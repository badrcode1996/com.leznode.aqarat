"use strict";

/**
 * Builds the contract (گرێبەست) HTML — rent or sale — rendered to PDF by
 * headless Chrome so Kurdish/Arabic shaping is correct. The company band
 * (thead) and contact footer (tfoot) repeat on every page. Clauses come from
 * the per-company template (or the built-in defaults) with {token}s filled in.
 */

const {DEFAULTS} = require("./contract_defaults");

const CURRENCY_LABEL = {IQD: "دیناری عێراقی", USD: "دۆلاری ئەمریکی"};

const esc = (s) =>
  String(s == null ? "" : s)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");

const money = (n) => Number(n || 0).toLocaleString("en-US");

function fmtDate(d) {
  if (!d) return "";
  const dt = d instanceof Date ? d : new Date(d);
  const y = dt.getFullYear();
  const m = String(dt.getMonth() + 1).padStart(2, "0");
  const day = String(dt.getDate()).padStart(2, "0");
  return `${y}/${m}/${day}`;
}

function tokensFor(c, company) {
  const cn = company.nameKu || "کۆمپانیا";
  const cur = CURRENCY_LABEL[c.dinar_dolar] || "";
  const common = {
    company: cn,
    contract_number: String(c.contract_number || ""),
    party1: c.party1_name || "",
    party2: c.party2_name || "",
    property_type: c.property_type || "",
    project: c.project_name || "",
    property_number: c.property_number || "",
    area: (c.area || 0) + " م²",
    currency: cur,
  };
  if (c.contract_type === "rent") {
    return Object.assign(common, {
      rent_amount: money(c.rent_amount),
      period_months: String(c.rental_period_months || 0),
      start_date: fmtDate(c.start_date),
      end_date: fmtDate(c.end_date),
      down_payment: money(c.down_payment),
      down_payment_months: String(c.down_payment_months || 0),
      payment_frequency: String(c.payment_frequency_months || 0),
      guarantee: money(c.guarantee_amount),
      purpose: c.rental_purpose || "",
      grace_period: c.grace_period || "",
      late_fee: money(c.late_fee_per_day),
    });
  }
  return Object.assign(common, {
    total_price: money(c.total_price),
    down_payment: money(c.down_payment),
    payment_method: c.payment_method || "",
    delivery_date: fmtDate(c.delivery_date),
    late_fee: money(c.late_fee_per_day),
    withdrawal: money(c.withdrawal_amount),
    commission: String(c.commission_rate || 0) + "%",
    lawyer: c.lawyer || "",
  });
}

const applyTokens = (s, tokens) =>
  String(s).replace(/\{(\w+)\}/g, (m, k) => (k in tokens ? tokens[k] : m));

/**
 * @param {object} o {contract, company, template, fontRegB64, fontBoldB64}
 * @return {string} HTML document
 */
function buildContractHtml(o) {
  const c = o.contract || {};
  const company = o.company || {};
  const t = o.template || {};
  const isRent = c.contract_type === "rent";

  const accent = "#" + (t.primary_color || DEFAULTS.primary_color);
  const fs = (t.clause_font_size || DEFAULTS.clause_font_size) + "px";
  const title = isRent ?
    (t.rent_title || DEFAULTS.rent_title) :
    (t.sale_title || DEFAULTS.sale_title);
  let clauses = isRent ? t.rent_clauses : t.sale_clauses;
  if (!Array.isArray(clauses) || clauses.length === 0) {
    clauses = isRent ? DEFAULTS.rent_clauses : DEFAULTS.sale_clauses;
  }
  const tokens = tokensFor(c, company);

  const names = [company.nameKu, company.nameAr, company.nameEn]
      .filter(Boolean);
  const logo = company.logo_data_uri ?
    `<img class="logo" src="${company.logo_data_uri}">` : "";
  // Faint full-page watermark of the company logo (all plans).
  const watermark = company.logo_data_uri ?
    `<img class="watermark" src="${company.logo_data_uri}">` : "";

  const row = (label, val) =>
    `<div class="r"><span class="rl">${esc(label)}</span>` +
    `<span class="rv">${esc(val)}</span></div>`;

  const card = isRent ? [
    row("ژمارەی گرێبەست:", c.contract_number),
    row("لایەنی یەکەم (خاوەن موڵک):", c.party1_name),
    row("لایەنی دووەم (کرێچی):", c.party2_name),
    row("جۆری موڵک:", c.property_type),
    row("پڕۆژە / گەڕەک:", c.project_name),
    row("ژمارەی عەقار:", c.property_number),
    row("ڕووبەر:", (c.area || 0) + " م²"),
  ].join("") : [
    row("ژمارەی گرێبەست:", c.contract_number),
    row("لایەنی یەکەم (فرۆشیار):", c.party1_name),
    row("لایەنی دووەم (کڕیار):", c.party2_name),
    row("جۆری موڵک:", c.property_type),
    row("پڕۆژە / گەڕەک:", c.project_name),
    row("ژمارەی عەقار:", c.property_number),
    row("ڕووبەر:", (c.area || 0) + " م²"),
    (c.commission_rate ?
      row("ڕێژەی عمولە:", c.commission_rate + "% — هەر لایەک " +
        money((Number(c.total_price) || 0) * Number(c.commission_rate) / 100) +
        " " + (CURRENCY_LABEL[c.dinar_dolar] || "")) : ""),
  ].join("");

  const clausesHtml = clauses
      .map((cl, i) =>
        `<div class="clause">${i + 1}- ${esc(applyTokens(cl, tokens))}</div>`)
      .join("");

  const notes = (c.notes && c.notes.trim()) ?
    `<div class="notes">تێبینی: ${esc(c.notes)}</div>` : "";

  const sign = (label, name) =>
    `<div class="sg"><div class="sgl">${esc(label)}</div>` +
    `<div class="sgline"></div><div class="sgn">${esc(name)}</div></div>`;

  const footerCells = [
    [company.phone1, company.phone2].filter(Boolean).join(" / "),
    company.address,
  ].filter(Boolean);

  return `<!doctype html><html lang="ckb"><head><meta charset="utf-8">
<style>
@font-face{font-family:'Speda';src:url(data:font/ttf;base64,${o.fontRegB64}) format('truetype');font-weight:normal;}
@font-face{font-family:'Speda';src:url(data:font/ttf;base64,${o.fontBoldB64}) format('truetype');font-weight:bold;}
*{box-sizing:border-box;margin:0;padding:0;}
@page{size:A4;margin:14mm 16mm 24mm;}
body{font-family:'Speda';direction:rtl;color:#111;font-size:${fs};line-height:1.6;}
table.page{width:100%;border-collapse:collapse;}
thead{display:table-header-group;}
.band{display:flex;align-items:center;padding-bottom:6px;}
.band .names{flex:1;}
.band .names div{font-weight:bold;font-size:14px;}
.band .logo{width:56px;height:56px;object-fit:contain;margin-right:10px;}
.bandline{border-bottom:1.2px solid ${accent};margin-bottom:8px;}
.title{text-align:center;font-size:22px;font-weight:bold;color:${accent};
  margin:6px 0 8px;}
.card{border:1px solid ${accent};border-radius:6px;padding:10px;margin-bottom:12px;}
.card .ct{font-weight:bold;font-size:13px;color:${accent};margin-bottom:6px;}
.r{display:flex;margin:2px 0;}
.r .rl{width:160px;font-weight:bold;}
.r .rv{flex:1;}
.chead{font-weight:bold;font-size:12px;color:${accent};margin-bottom:6px;}
.clause{text-align:justify;margin-bottom:6px;}
.notes{margin-top:8px;}
.signs{display:flex;gap:16px;margin-top:28px;}
.sg{flex:1;text-align:center;}
.sgl{font-weight:bold;}
.sgline{border-top:1px solid #000;width:120px;margin:18px auto 4px;}
.sgn{font-size:11px;}
.foot{position:fixed;bottom:0;left:0;right:0;padding-top:6px;
  border-top:.8px solid #bbb;display:flex;justify-content:space-between;
  font-size:9px;background:#fff;}
/* Company-logo watermark: fixed + centred so it repeats faintly behind the
   text on every printed page. Available on all plans. */
.watermark{position:fixed;top:50%;left:50%;transform:translate(-50%,-50%);
  width:62%;opacity:.06;z-index:-1;pointer-events:none;}
</style></head><body>
${watermark}
<table class="page">
  <thead><tr><td>
    <div class="band"><div class="names">${names.map((n) =>
    `<div>${esc(n)}</div>`).join("")}</div>${logo}</div>
    <div class="bandline"></div>
  </td></tr></thead>
  <tbody><tr><td>
    <div class="title">${esc(title)}</div>
    <div class="card"><div class="ct">زانیاری گرێبەست</div>${card}</div>
    <div class="chead">هەردوو لایەن ڕێکەوتن لەسەر ئەم خاڵانەی خوارەوە (بەندەکان):</div>
    ${clausesHtml}
    ${notes}
    <div class="signs">
      ${sign("لایەنی یەکەم", c.party1_name)}
      ${sign("کارمەندی بەرپرس", c.agent_name)}
      ${sign("لایەنی دووەم", c.party2_name)}
    </div>
  </td></tr></tbody>
</table>
${footerCells.length ? `<div class="foot">${footerCells.map((x) =>
    `<span>${esc(x)}</span>`).join("")}</div>` : ""}
</body></html>`;
}

module.exports = {buildContractHtml};
