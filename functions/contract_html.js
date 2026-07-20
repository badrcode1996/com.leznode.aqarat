"use strict";

/**
 * Builds the contract (گرێبەست) HTML — rent or sale — rendered to PDF by
 * headless Chrome so Kurdish/Arabic shaping is correct. The company band
 * (thead) and contact footer (tfoot) repeat on every page. Clauses come from
 * the per-company template (or the built-in defaults) with {token}s filled in.
 */

const {DEFAULTS} = require("./contract_defaults");
const {resolveDesign} = require("./designs");

const CURRENCY_LABEL = {IQD: "دیناری عێراقی", USD: "دۆلاری ئەمریکی"};

const esc = (s) =>
  String(s == null ? "" : s)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");

// esc() is for text nodes; a value going into an attribute must also have its
// quotes escaped or it can close the attribute and inject markup.
const escAttr = (s) => esc(s).replace(/"/g, "&quot;");

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
 * Everything a contract layout needs, with the data work already done: tokens
 * substituted into the clauses, dates and money formatted, the logo turned
 * into a data URI. A per-company design in designs/ calls this and emits its
 * own markup, so a bespoke layout never re-implements the data handling — see
 * designs/index.js.
 *
 * @param {object} o {contract, company, template, fontRegB64, fontBoldB64,
 *   attachments, companyId}
 * @return {object} prepared values (see the returned object's keys)
 */
function contractViewModel(o) {
  const c = o.contract || {};
  const company = o.company || {};
  const t = o.template || {};
  const isRent = c.contract_type === "rent";
  const tokens = tokensFor(c, company);

  const pick = (...lists) =>
    lists.find((l) => Array.isArray(l) && l.length > 0) || [];
  // Migration shim: rent_clauses_house is the newest edit on templates saved
  // while clauses were split per property kind. Drop once all are re-saved.
  const rawClauses = isRent ?
    pick(t.rent_clauses_house, t.rent_clauses, DEFAULTS.rent_clauses) :
    pick(t.sale_clauses, DEFAULTS.sale_clauses);

  return {
    contract: c,
    company,
    template: t,
    isRent,
    tokens,
    accent: "#" + (t.primary_color || DEFAULTS.primary_color),
    fontSize: (t.clause_font_size || DEFAULTS.clause_font_size) + "px",
    title: isRent ?
      (t.rent_title || DEFAULTS.rent_title) :
      (t.sale_title || DEFAULTS.sale_title),
    /** Clause texts with every {token} already substituted. */
    clauses: rawClauses.map((cl) => applyTokens(cl, tokens)),
    /** Company name lines, blanks dropped. */
    names: [company.nameKu, company.nameAr, company.nameEn].filter(Boolean),
    logoUri: company.logo_data_uri || "",
    /** Attachment photos as data: URIs, for appendix pages. */
    attachments: Array.isArray(o.attachments) ? o.attachments : [],
    /** [label, value] pairs describing the property. */
    propertyPairs: [
      ["جۆری موڵک:", c.property_type || ""],
      ["پڕۆژە / گەڕەک:", c.project_name || ""],
      ["ژمارەی عەقار:", c.property_number || ""],
      ["ڕووبەر:", (c.area || 0) + " م²"],
    ],
    footerCells: [
      [company.phone1, company.phone2].filter(Boolean).join(" / "),
      company.address,
    ].filter(Boolean),
    fontRegB64: o.fontRegB64,
    fontBoldB64: o.fontBoldB64,
    // Helpers, so a design doesn't re-implement them.
    esc, money, fmtDate, applyTokens,
  };
}

/**
 * @param {object} o {contract, company, template, fontRegB64, fontBoldB64,
 *   attachments} — attachments is an array of image data: URIs appended as
 *   one-per-page appendix pages.
 * @return {string} HTML document
 */
function buildContractHtml(o) {
  const c = o.contract || {};
  const company = o.company || {};
  const t = o.template || {};
  const isRent = c.contract_type === "rent";

  // Per-company design: a full layout takeover wins outright; otherwise its
  // css is appended to the base stylesheet below and overrides it.
  const design = resolveDesign(o.companyId);
  if (typeof design.contractHtml === "function") {
    return design.contractHtml(contractViewModel(o), o);
  }

  const vm = contractViewModel(o);
  const {accent, title, names, propertyPairs: propPairs} = vm;
  const fs = vm.fontSize;
  const logo = company.logo_data_uri ?
    `<img class="logo" src="${escAttr(company.logo_data_uri)}">` : "";
  // Faint full-page watermark of the company logo (all plans).
  const watermark = company.logo_data_uri ?
    `<img class="watermark" src="${escAttr(company.logo_data_uri)}">` : "";

  const row = (label, val) =>
    `<div class="r"><span class="rl">${esc(label)}</span>` +
    `<span class="rv">${esc(val)}</span></div>`;

  // The four property attributes collapse onto one line ("label: value - ...")
  // so the info card stays compact. Each pair is kept unbreakable.
  const propLine = (pairs) =>
    `<div class="r ri">` +
    pairs.map((p) => `<span class="pp"><b>${esc(p[0])}</b> ${esc(p[1])}</span>`)
        .join('<span class="sep"> - </span>') +
    `</div>`;

  const card = isRent ? [
    row("ژمارەی گرێبەست:", c.contract_number),
    row("لایەنی یەکەم (خاوەن موڵک):", c.party1_name),
    row("لایەنی دووەم (کرێچی):", c.party2_name),
    propLine(propPairs),
  ].join("") : [
    row("ژمارەی گرێبەست:", c.contract_number),
    row("لایەنی یەکەم (فرۆشیار):", c.party1_name),
    row("لایەنی دووەم (کڕیار):", c.party2_name),
    propLine(propPairs),
    (c.commission_rate ?
      row("ڕێژەی عمولە:", c.commission_rate + "% — هەر لایەک " +
        money((Number(c.total_price) || 0) * Number(c.commission_rate) / 100) +
        " " + (CURRENCY_LABEL[c.dinar_dolar] || "")) : ""),
  ].join("");

  // vm.clauses already has its {token}s substituted.
  const clausesHtml = vm.clauses
      .map((cl, i) => `<div class="clause">${i + 1}- ${esc(cl)}</div>`)
      .join("");

  const notes = (c.notes && c.notes.trim()) ?
    `<div class="notes">تێبینی: ${esc(c.notes)}</div>` : "";

  const sign = (label, name) =>
    `<div class="sg"><div class="sgl">${esc(label)}</div>` +
    `<div class="sgline"></div><div class="sgn">${esc(name)}</div></div>`;

  const footerCells = vm.footerCells;

  // Attachments print four-up on plain pages after the contract. They sit
  // OUTSIDE table.page on purpose: inside it the thead company band would
  // repeat over every photo page.
  const attachmentPages = [];
  for (let i = 0; i < vm.attachments.length; i += 4) {
    attachmentPages.push(vm.attachments.slice(i, i + 4));
  }
  // Full pages keep the 2x2 grid. A trailing page with 1 or 2 photos drops
  // to a 1-column layout so those photos fill the page instead of sitting
  // tiny in a quarter cell (portrait scans especially).
  const attachmentsHtml = attachmentPages
      .map((page) => {
        const cls = page.length <= 2 ? "attachpage sparse" : "attachpage";
        return `<div class="${cls}">` +
          page.map((uri) => `<div class="attachcell">` +
            `<img src="${escAttr(uri)}"></div>`).join("") +
          `</div>`;
      })
      .join("");

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
.card{border:1px solid ${accent};border-radius:6px;padding:8px 10px;margin-bottom:10px;}
.card .ct{font-weight:bold;font-size:13px;color:${accent};margin-bottom:6px;}
.r{display:flex;align-items:baseline;margin:3px 0;}
.r .rl{font-weight:bold;white-space:nowrap;margin-left:6px;}
.r .rv{flex:1;}
/* The property line: normal inline flow so pairs wrap only between each
   other, never mid-pair. */
.ri{display:block;line-height:1.8;}
.ri .pp{white-space:nowrap;}
.ri .sep{color:#aaa;}
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
/* Appendix: four photos to a plain page, 2x2. Each page is its own grid so
   the break lands between pages, never inside a row. The opaque white
   background + z-index cover the fixed watermark and footer, which would
   otherwise repeat onto these pages — the appendix is meant to be bare
   paper, with no company design on it. */
.attachpage{page-break-before:always;display:grid;
  grid-template-columns:1fr 1fr;grid-auto-rows:1fr;gap:8mm;height:259mm;
  position:relative;z-index:5;background:#fff;}
/* Trailing page with 1-2 photos: one column so each fills the page. */
.attachpage.sparse{grid-template-columns:1fr;}
.attachcell{display:flex;align-items:center;justify-content:center;
  overflow:hidden;}
.attachcell img{max-width:100%;max-height:100%;object-fit:contain;}
/* Company-logo watermark: fixed + centred so it repeats faintly behind the
   text on every printed page. Available on all plans. */
.watermark{position:fixed;top:50%;left:50%;transform:translate(-50%,-50%);
  width:62%;opacity:.06;z-index:-1;pointer-events:none;}
${design.css || ""}
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
    <div class="chead">هەردوو لایەن ڕێکەوتن لەسەر ئەم خاڵانەی خوارەوە:</div>
    ${clausesHtml}
    ${notes}
    <div class="signs">
      ${sign("لایەنی یەکەم", c.party1_name)}
      ${sign("کارمەندی بەرپرس", c.agent_name)}
      ${sign("لایەنی دووەم", c.party2_name)}
    </div>
  </td></tr></tbody>
</table>
${attachmentsHtml}
${footerCells.length ? `<div class="foot">${footerCells.map((x) =>
    `<span>${esc(x)}</span>`).join("")}</div>` : ""}
</body></html>`;
}

module.exports = {buildContractHtml, contractViewModel};
