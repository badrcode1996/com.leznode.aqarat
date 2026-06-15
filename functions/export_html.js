"use strict";

/**
 * Builds the super-admin data-export report HTML (a company's contracts +
 * receipts as two tables), rendered to PDF by headless Chrome so Kurdish
 * shaping is correct. Landscape A4.
 */

const CURRENCY_LABEL = {IQD: "دیناری عێراقی", USD: "دۆلاری ئەمریکی"};
const RECEIPT_TITLE = {
  external_receive: "پسولەی پارە وەرگرتن",
  external_pay: "پسولەی پارەدان",
  rent_receive: "پسولەی وەرگرتنی کرێ",
  rent_pay: "پسولەی دانەوەی کرێ",
};

const esc = (s) =>
  String(s == null ? "" : s)
      .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
const money = (n) => Number(n || 0).toLocaleString("en-US");
function fmtDate(d) {
  if (!d) return "";
  const dt = d instanceof Date ? d : new Date(d);
  return `${dt.getFullYear()}/${String(dt.getMonth() + 1).padStart(2, "0")}/` +
    `${String(dt.getDate()).padStart(2, "0")}`;
}

const CONTRACT_HEADERS =
  ["ژمارە", "جۆر", "لایەنی یەکەم", "لایەنی دووەم", "موڵک", "پڕۆژە",
    "بڕ / نرخ", "دراو", "بەروار"];
const RECEIPT_HEADERS =
  ["ژمارە", "جۆر", "کەس", "بڕ", "دراو", "مەبەست", "لق", "بەروار"];

const contractRow = (k) => k.contract_type === "rent" ? [
  k.contract_number, "کرێ", k.party1_name, k.party2_name, k.property_type,
  k.project_name, money(k.rent_amount), CURRENCY_LABEL[k.dinar_dolar] || "",
  fmtDate(k.start_date),
] : [
  k.contract_number, "فرۆشتن", k.party1_name, k.party2_name, k.property_type,
  k.project_name, money(k.total_price), CURRENCY_LABEL[k.dinar_dolar] || "",
  fmtDate(k.delivery_date),
];

const receiptRow = (r) => [
  r.receipt_number, RECEIPT_TITLE[r.type] || r.type, r.person_name,
  money(r.amount), CURRENCY_LABEL[r.dinar_dolar] || "", r.payment_purpose,
  r.branch, fmtDate(r.date),
];

function table(headers, rows) {
  if (!rows.length) {
    return `<div class="empty">— هیچ تۆمارێک نییە —</div>`;
  }
  const th = headers.map((h) => `<th>${esc(h)}</th>`).join("");
  const tr = rows.map((r) =>
    `<tr>${r.map((c) => `<td>${esc(c)}</td>`).join("")}</tr>`).join("");
  return `<table class="data"><thead><tr>${th}</tr></thead>` +
    `<tbody>${tr}</tbody></table>`;
}

/**
 * @param {object} o {company, contracts, receipts, fontRegB64, fontBoldB64}
 * @return {string} HTML document
 */
function buildExportHtml(o) {
  const company = o.company || {};
  const contracts = o.contracts || [];
  const receipts = o.receipts || [];
  const name = company.nameKu || company.nameAr || company.nameEn || "";

  return `<!doctype html><html lang="ckb"><head><meta charset="utf-8">
<style>
@font-face{font-family:'Speda';src:url(data:font/ttf;base64,${o.fontRegB64}) format('truetype');font-weight:normal;}
@font-face{font-family:'Speda';src:url(data:font/ttf;base64,${o.fontBoldB64}) format('truetype');font-weight:bold;}
*{box-sizing:border-box;margin:0;padding:0;}
@page{size:A4 landscape;margin:12mm;}
body{font-family:'Speda';direction:rtl;color:#111;font-size:10px;}
h1{font-size:18px;color:#0F2C59;}
.date{font-size:10px;color:#666;margin-bottom:12px;}
h2{font-size:13px;color:#1E4D8B;margin:14px 0 6px;}
table.data{width:100%;border-collapse:collapse;}
table.data th,table.data td{border:.5px solid #aaa;padding:4px 6px;
  text-align:right;}
table.data th{background:#E8EFF7;font-weight:bold;}
.empty{color:#666;}
</style></head><body>
<h1>ڕاپۆرتی ${esc(name)}</h1>
<div class="date">بەروار: ${fmtDate(new Date())}</div>
<h2>گرێبەستەکان (${contracts.length})</h2>
${table(CONTRACT_HEADERS, contracts.map(contractRow))}
<h2>پسولەکان (${receipts.length})</h2>
${table(RECEIPT_HEADERS, receipts.map(receiptRow))}
</body></html>`;
}

module.exports = {buildExportHtml};
