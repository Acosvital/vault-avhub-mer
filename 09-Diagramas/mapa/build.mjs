// Gera o mapa a partir de template.html + fichas/*.json.
// Uso: node build.mjs
// Cria duas versões ao lado deste arquivo:
//   mapa-acos-vital.html  sem links (serve para o artifact e para abrir solto)
import { readFileSync, readdirSync, writeFileSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const aqui = dirname(fileURLToPath(import.meta.url));
const vault = join(aqui, "..", "..");
const dirFichas = join(aqui, "fichas");

// Nota(s) de raia de cada setor, como caminho no site de consulta (pasta/arquivo sem .md).
const R = "02-Fluxo-de-Atividades/";
const NOTAS = {
  vendas: [["Vendas: liberação do pedido", R + "01-Vendas-Liberacao"], ["Proposta e pedido de venda", R + "11-Proposta-e-Pedido-de-Venda"]],
  orcamento: [["Orçamento e base de preço", R + "12-Orcamento-Base-de-Preco"]],
  pcp: [["PCP: triagem e destinação", R + "02-PCP-Triagem-e-Destinacao"]],
  estoque: [["Estoque: atendimento e despacho", R + "03-Estoque-Atendimento-e-Despacho"]],
  compras: [["Circuito de compra", R + "04-Circuito-de-Compra"]],
  recebimento: [["Recebimento", R + "05-Recebimento"]],
  "qualidade-entrada": [["Qualidade de entrada", R + "06-Qualidade-Entrada"]],
  producao: [["Produção e roteiro", R + "07-Producao-e-Roteiro"]],
  "qualidade-saida": [["Qualidade de saída", R + "08-Qualidade-Saida"]],
  expedicao: [["Expedição", R + "09-Expedicao"]],
  fiscal: [["Fiscal e Omie", R + "10-Fiscal-Omie"]],
  controladoria: [["Custo real e comissão no fluxo", R + "13-Custo-Real-e-Comissao-no-Fluxo"], ["Regras e estados da comissão nova", "03-Sistemas/Comissao/04-Regras-e-Estados-da-Comissao-Nova"]]
};
const GERAIS = [["Registro de decisões", "08-Decisoes/Registro-de-Decisoes"], ["Painel de contratos", "06-Contratos/Painel-de-Contratos"], ["Fluxo mestre (o diagrama completo)", R + "00-Fluxo-Mestre-0b"]];

// id do contrato -> caminho no site de consulta
const contratos = new Map();
for (const pasta of ["Ativos", "Entregues", "Arquivados"]) {
  const dir = join(vault, "06-Contratos", pasta);
  if (!existsSync(dir)) continue;
  for (const n of readdirSync(dir)) {
    const m = n.match(/^((?:LOG|API|SQL)-\d+[a-z]?)-.*\.md$/);
    if (m) contratos.set(m[1], `06-Contratos/${pasta}/${n.replace(/\.md$/, "")}`);
  }
}
const url = (p) => "/" + encodeURI(p);

const fichas = readdirSync(dirFichas)
  .filter((n) => n.endsWith(".json"))
  .map((n) => JSON.parse(readFileSync(join(dirFichas, n), "utf8")));

const template = readFileSync(join(aqui, "template.html"), "utf8");
const montar = (dados, base) => {
  const json = JSON.stringify(dados).replace(/<\//g, "<\\/");
  return template.replace("/*__DATA__*/[]", () => json).replace("/*__BASE__*/null", () => JSON.stringify(base));
};

// versão sem links
writeFileSync(join(aqui, "mapa-acos-vital.html"), montar(fichas, null));

// versão do site, com links
let semContrato = 0;
const comLinks = fichas.map((f) => ({
  ...f,
  notas: [...(NOTAS[f.id] || []), ...GERAIS].map(([titulo, p]) => ({ titulo, href: url(p) })),
  contratos: (f.contratos || []).map((c) => {
    const p = contratos.get(c.id);
    if (!p) { semContrato++; return c; }
    return { ...c, href: url(p) };
  })
}));

console.log(`${fichas.length} fichas · mapa-acos-vital.html · ${semContrato} contratos sem nota achada`);
