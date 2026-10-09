// Extrai do BFF do av-hub (app/api/**/route.ts) as chamadas à API: método, caminho, tela exigida e cabeçalho.
// Leitura por regex: serve para o DBA mapear auth.rotas_telas; cada linha deve ser conferida no arquivo.
const fs = require('fs');
const path = require('path');

const FRONT = process.argv[2];
const OUT = process.argv[3];
const API = path.join(FRONT, 'app', 'api');

function walk(dir, acc = []) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, acc);
    else if (e.name === 'route.ts') acc.push(p);
  }
  return acc;
}

// constantes TELA_* e mapas por fonte
const telas = {};
function lerConstantes(dir) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) { if (!/node_modules|\.next|\.claude/.test(e.name)) lerConstantes(p); }
    else if (/\.ts$/.test(e.name)) {
      const t = fs.readFileSync(p, 'utf8');
      for (const m of t.matchAll(/(?:export\s+)?const\s+(TELA_[A-Z_]+)\s*=\s*['"]([^'"]+)['"]/g)) telas[m[1]] = m[2];
    }
  }
}
lerConstantes(path.join(FRONT, 'lib'));

const POR_FONTE_PEDIDOS = 'pedidos-equipe | pcp-pedidos | meus-pedidos';
const POR_FONTE_NOTAS = 'notas-equipe | pcp-notas | minhas-notas';

function bffPath(file) {
  const rel = path.relative(path.join(FRONT, 'app'), path.dirname(file)).split(path.sep);
  return '/' + rel.map((s) => s.replace(/^\[\.\.\.(.+)\]$/, '{...$1}').replace(/^\[(.+)\]$/, '{$1}')).join('/');
}

function limparCaminho(raw) {
  let p = raw.split('?')[0];
  p = p.replace(/\$\{[^}]*\}/g, '{x}');
  return p || '(dinâmico)';
}

function analisar(file) {
  const src = fs.readFileSync(file, 'utf8');
  const heads = [...src.matchAll(/export\s+(?:async\s+)?function\s+(GET|POST|PUT|PATCH|DELETE)\s*\(/g)];
  const linhas = [];
  heads.forEach((m, i) => {
    const ini = m.index;
    const fim = i + 1 < heads.length ? heads[i + 1].index : src.length;
    const bloco = src.slice(ini, fim);
    const metodoBff = m[1];

    // cabeçalho de autenticação
    let auth = null;
    if (/headersComIdentidade|comEscopoUnidade/.test(bloco)) auth = 'Bearer (cai para x-api-key sem token)';
    else if (/headersComercial/.test(bloco)) auth = 'Bearer do Comercial';
    else if (/headersCompras/.test(bloco)) auth = 'só x-api-key';
    else if (/headersApi\b/.test(bloco)) auth = 'só x-api-key';
    else if (/['"]x-api-key['"]/.test(bloco)) auth = 'só x-api-key (inline)';

    // permissão exigida no BFF
    const perms = new Set();
    for (const p of bloco.matchAll(/requirePermission\(\s*(\[[^\]]*\]|'[^']*'|"[^"]*"|[A-Za-z_]+)\s*,\s*'(\w+)'/g)) {
      let tela = p[1];
      if (/^[A-Z_]+$/.test(tela) && telas[tela]) tela = telas[tela];
      else if (/^[A-Za-z_]+$/.test(tela) && !/^'/.test(p[1])) tela = '(tela definida em código)';
      tela = tela.replace(/[\[\]'" ]/g, '').replace(/,/g, ' | ');
      perms.add(`${tela} (${p[2].replace('pode_', '')})`);
    }
    if (/negarSemPermissaoNotas\(/.test(bloco)) perms.add(`${POR_FONTE_NOTAS} (visualizar)`);
    else if (/negarSemPermissao\(/.test(bloco)) perms.add(`${POR_FONTE_PEDIDOS} (visualizar)`);

    // caminhos da API
    const alvos = [];
    for (const a of bloco.matchAll(/\$\{process\.env\.(API_URL|COMERCIAL_API_URL)\}((?:\$\{[^}]*\}|[^`'"\s$])*)/g)) {
      const dest = a[1] === 'COMERCIAL_API_URL' ? 'api-comercial' : 'api-acos-vital';
      const resto = a[2];
      alvos.push({ dest, caminho: resto.startsWith('${') && !resto.replace(/\$\{[^}]*\}/g, '').startsWith('/') ? '(dinâmico: ver arquivo)' : limparCaminho(resto) });
    }
    // chamadas por helper (caminho literal passado como argumento)
    const ehComercial = file.split(path.sep).join('/').includes('/app/api/comercial/');
    if (alvos.length === 0 && /@\/lib\/(compras|api)\//.test(src)) {
      for (const l of bloco.matchAll(/['"`](\/[a-z_][a-z0-9_\-\/${}]*)['"`]/g)) {
        if (l[1].length > 3) alvos.push({ dest: ehComercial ? 'api-comercial' : 'api-acos-vital', caminho: limparCaminho(l[1]) + '  (via helper)' });
      }
    }
    const metodosFetch = new Set([...bloco.matchAll(/method:\s*['"](POST|PUT|PATCH|DELETE)['"]/g)].map((x) => x[1]));
    const metodoApi = metodosFetch.size ? [...metodosFetch].join('/') : 'GET';

    const unicos = [...new Map(alvos.map((a) => [a.dest + a.caminho, a])).values()];
    if (unicos.length === 0) {
      linhas.push({ bff: bffPath(file), metodoBff, api: null, auth, perms: [...perms] });
    } else {
      for (const a of unicos) linhas.push({ bff: bffPath(file), metodoBff, metodoApi: metodosFetch.size ? metodoApi : metodoBff === 'GET' ? 'GET' : metodoBff, api: a, auth: auth ?? '?', perms: [...perms] });
    }
  });
  return linhas;
}

const todas = walk(API).flatMap(analisar);
const comApi = todas.filter((l) => l.api);
const semApi = todas.filter((l) => !l.api);
const semBearer = comApi.filter((l) => /^só x-api-key|^\?$/.test(l.auth));
const comBearer = comApi.filter((l) => !/^só x-api-key|^\?$/.test(l.auth));

const esc = (s) => String(s).replace(/\|/g, '\\|');
const linhaTab = (l) => `| \`${esc(l.bff)}\` | ${l.metodoBff} | ${l.metodoApi} \`${esc(l.api.caminho)}\` (${l.api.dest}) | ${l.perms.length ? esc(l.perms.join('; ')) : '—'} | ${esc(l.auth)} |`;

// DBA: caminho da API único -> telas e ações exigidas no BFF (só os sem Bearer)
const agg = new Map();
for (const l of semBearer.filter((x) => x.api.dest === 'api-acos-vital')) {
  const k = `${l.metodoApi} ${l.api.caminho} (${l.api.dest})`;
  if (!agg.has(k)) agg.set(k, { metodo: l.metodoApi, caminho: l.api.caminho, dest: l.api.dest, telas: new Set(), bffs: new Set() });
  const o = agg.get(k);
  l.perms.forEach((p) => o.telas.add(p));
  o.bffs.add(l.bff);
}
const aggSorted = [...agg.values()].sort((a, b) => a.caminho.localeCompare(b.caminho) || a.metodo.localeCompare(b.metodo));

const out = [];
out.push(`<!--CONTAGENS ${JSON.stringify({ rotasBff: new Set(todas.map((l) => l.bff)).size, handlers: todas.length, comApi: comApi.length, semBearer: semBearer.length, comBearer: comBearer.length, semApi: semApi.length, unicosDba: aggSorted.length })}-->`);
out.push('## A. Rotas da API a mapear em `auth.rotas_telas` (hoje chamadas SEM Bearer)');
out.push('');
out.push('| Método | Caminho na API | Tela(s) e ação exigidas no BFF | Rotas do BFF que chamam |');
out.push('|---|---|---|---|');
for (const o of aggSorted) out.push(`| ${o.metodo} | \`${esc(o.caminho)}\` (${o.dest}) | ${o.telas.size ? esc([...o.telas].join('; ')) : '—'} | ${[...o.bffs].slice(0, 3).map((b) => '`' + esc(b) + '`').join(', ')}${o.bffs.size > 3 ? ` (+${o.bffs.size - 3})` : ''} |`);
out.push('');
out.push('## B. Detalhe por rota do BFF: SEM Bearer hoje');
out.push('');
out.push('| Rota do BFF | Método do BFF | Chamada à API | Tela exigida no BFF | Cabeçalho |');
out.push('|---|---|---|---|---|');
for (const l of semBearer.sort((a, b) => a.bff.localeCompare(b.bff))) out.push(linhaTab(l));
out.push('');
out.push('## C. Detalhe por rota do BFF: COM Bearer hoje');
out.push('');
out.push('| Rota do BFF | Método do BFF | Chamada à API | Tela exigida no BFF | Cabeçalho |');
out.push('|---|---|---|---|---|');
for (const l of comBearer.sort((a, b) => a.bff.localeCompare(b.bff))) out.push(linhaTab(l));
out.push('');
out.push('## D. Handlers sem chamada identificada à API');
out.push('');
out.push('| Rota do BFF | Método | Tela exigida no BFF |');
out.push('|---|---|---|');
for (const l of semApi.sort((a, b) => a.bff.localeCompare(b.bff))) out.push(`| \`${esc(l.bff)}\` | ${l.metodoBff} | ${l.perms.length ? esc(l.perms.join('; ')) : '—'} |`);
fs.writeFileSync(OUT, out.join('\n'), 'utf8');
console.log(out[0]);
