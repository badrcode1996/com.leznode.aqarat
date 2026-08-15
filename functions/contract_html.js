"use strict";

/**
 * Builds the contract (گرێبەست) HTML — rent or sale — rendered to PDF by
 * headless Chrome so Kurdish/Arabic shaping is correct. The company band
 * (thead) and contact footer (tfoot) repeat on every page. Clauses come from
 * the per-company template (or the built-in defaults) with {token}s filled in.
 */

const {DEFAULTS} = require("./contract_defaults");
const {resolveDesign} = require("./designs");

/**
 * Every fixed string on the document, per language. The contract is rendered
 * in ONE language — Kurdish or Arabic — never both on a page: this is a legal
 * document that gets filed with the land registry or a court, and a bilingual
 * body would double a 26-clause rent contract's page count.
 *
 * Clause bodies are NOT here — they are legal text and live in the company's
 * template (`rent_clauses_ar` / `sale_clauses_ar`), written by the company's
 * own lawyer. A contract with no Arabic clauses stored cannot be rendered in
 * Arabic at all; index.js refuses before reaching this file.
 */
const L = {
  ku: {
    currency: {IQD: "دیناری عێراقی", USD: "دۆلاری ئەمریکی"},
    company: "کۆمپانیا",
    areaUnit: " م²",
    cardTitle: "زانیاری گرێبەست",
    contractNo: "ژمارەی گرێبەست:",
    party1Rent: "لایەنی یەکەم (خاوەن موڵک):",
    party2Rent: "لایەنی دووەم (کرێچی):",
    party1Sale: "لایەنی یەکەم (فرۆشیار):",
    party2Sale: "لایەنی دووەم (کڕیار):",
    commission: "ڕێژەی عمولە:",
    commissionEach: " — هەر لایەک ",
    propertyType: "جۆری موڵک:",
    project: "پڕۆژە / گەڕەک:",
    propertyNo: "ژمارەی عەقار:",
    area: "ڕووبەر:",
    clausesHead: "هەردوو لایەن ڕێکەوتن لەسەر ئەم خاڵانەی خوارەوە:",
    notes: "تێبینی: ",
    sign1: "لایەنی یەکەم",
    signAgent: "کارمەندی بەرپرس",
    sign2: "لایەنی دووەم",
  },
  ar: {
    currency: {IQD: "دينار عراقي", USD: "دولار أمريكي"},
    company: "الشركة",
    areaUnit: " م²",
    cardTitle: "معلومات العقد",
    contractNo: "رقم العقد:",
    party1Rent: "الطرف الأول (مالك العقار):",
    party2Rent: "الطرف الثاني (المستأجر):",
    party1Sale: "الطرف الأول (البائع):",
    party2Sale: "الطرف الثاني (المشتري):",
    commission: "نسبة العمولة:",
    commissionEach: " — لكل طرف ",
    propertyType: "نوع العقار:",
    project: "المشروع / الحي:",
    propertyNo: "رقم العقار:",
    area: "المساحة:",
    clausesHead: "اتفق الطرفان على البنود الآتية:",
    notes: "ملاحظة: ",
    sign1: "الطرف الأول",
    signAgent: "الموظف المسؤول",
    sign2: "الطرف الثاني",
  },
};

/** Falls back to Kurdish for any value that is not exactly "ar". */
const langOf = (v) => (v === "ar" ? "ar" : "ku");

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

function tokensFor(c, company, lang) {
  const t = L[langOf(lang)];
  // An Arabic contract names the company in Arabic when the company has an
  // Arabic name on file; otherwise its Kurdish name still beats a placeholder.
  const cn = (langOf(lang) === "ar" ? company.nameAr || company.nameKu :
    company.nameKu) || t.company;
  const cur = t.currency[c.dinar_dolar] || "";
  const common = {
    company: cn,
    contract_number: String(c.contract_number || ""),
    party1: c.party1_name || "",
    party2: c.party2_name || "",
    property_type: c.property_type || "",
    project: c.project_name || "",
    property_number: c.property_number || "",
    area: (c.area || 0) + t.areaUnit,
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
  const lang = langOf(o.lang);
  const isAr = lang === "ar";
  const label = L[lang];
  const tokens = tokensFor(c, company, lang);

  const pick = (...lists) =>
    lists.find((l) => Array.isArray(l) && l.length > 0) || [];
  // Migration shim: rent_clauses_house is the newest edit on templates saved
  // while clauses were split per property kind. Drop once all are re-saved.
  const rawClauses = isAr ?
    (isRent ?
      pick(t.rent_clauses_ar, DEFAULTS.rent_clauses_ar) :
      pick(t.sale_clauses_ar, DEFAULTS.sale_clauses_ar)) :
    (isRent ?
      pick(t.rent_clauses_house, t.rent_clauses, DEFAULTS.rent_clauses) :
      pick(t.sale_clauses, DEFAULTS.sale_clauses));

  const kuTitle = isRent ?
    (t.rent_title || DEFAULTS.rent_title) :
    (t.sale_title || DEFAULTS.sale_title);
  const arTitle = (isRent ? t.rent_title_ar : t.sale_title_ar) ||
    (isRent ? DEFAULTS.rent_title_ar : DEFAULTS.sale_title_ar);

  return {
    contract: c,
    company,
    template: t,
    isRent,
    tokens,
    /** "ku" | "ar" — a custom design can branch on this. */
    lang,
    /** Every fixed string on the document, already in [lang]. */
    label,
    accent: "#" + (t.primary_color || DEFAULTS.primary_color),
    fontSize: (t.clause_font_size || DEFAULTS.clause_font_size) + "px",
    title: (isAr ? arTitle : "") || kuTitle,
    /** Clause texts with every {token} already substituted. */
    clauses: rawClauses.map((cl) => applyTokens(cl, tokens)),
    /**
     * Company name lines, blanks dropped. The Arabic edition leads with the
     * Arabic name and drops the Kurdish one, so the header matches the body.
     */
    names: (isAr ?
      [company.nameAr, company.nameEn] :
      [company.nameKu, company.nameAr, company.nameEn]).filter(Boolean),
    logoUri: company.logo_data_uri || "",
    /** Attachment photos as data: URIs, for appendix pages. */
    attachments: Array.isArray(o.attachments) ? o.attachments : [],
    /** [label, value] pairs describing the property. */
    propertyPairs: [
      [label.propertyType, c.property_type || ""],
      [label.project, c.project_name || ""],
      [label.propertyNo, c.property_number || ""],
      [label.area, (c.area || 0) + label.areaUnit],
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
  const {accent, title, names, propertyPairs: propPairs, lang, label: T} = vm;
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
    row(T.contractNo, c.contract_number),
    row(T.party1Rent, c.party1_name),
    row(T.party2Rent, c.party2_name),
    propLine(propPairs),
  ].join("") : [
    row(T.contractNo, c.contract_number),
    row(T.party1Sale, c.party1_name),
    row(T.party2Sale, c.party2_name),
    propLine(propPairs),
    (c.commission_rate ?
      row(T.commission, c.commission_rate + "%" + T.commissionEach +
        money((Number(c.total_price) || 0) * Number(c.commission_rate) / 100) +
        " " + (T.currency[c.dinar_dolar] || "")) : ""),
  ].join("");

  // vm.clauses already has its {token}s substituted.
  const clausesHtml = vm.clauses
      .map((cl, i) => `<div class="clause">${i + 1}- ${esc(cl)}</div>`)
      .join("");

  const notes = (c.notes && c.notes.trim()) ?
    `<div class="notes">${esc(T.notes)}${esc(c.notes)}</div>` : "";

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

  // 'DocFont' is deliberately generic: index.js embeds Speda for Kurdish and
  // Amiri for Arabic under the same family name, so the stylesheet — and any
  // per-company design that copies it — needs no language branch.
  return `<!doctype html><html lang="${lang === "ar" ? "ar" : "ckb"}"><head>
<meta charset="utf-8">
<style>
@font-face{font-family:'DocFont';src:url(data:font/ttf;base64,${o.fontRegB64}) format('truetype');font-weight:normal;}
@font-face{font-family:'DocFont';src:url(data:font/ttf;base64,${o.fontBoldB64}) format('truetype');font-weight:bold;}
*{box-sizing:border-box;margin:0;padding:0;}
@page{size:A4;margin:14mm 16mm 24mm;}
body{font-family:'DocFont';direction:rtl;color:#111;font-size:${fs};line-height:1.6;}
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
.signs{display:flex;gap:16px;margin-top:28px;break-inside:avoid;}
/* Filled in by __fitLayout so the signatures sit on the foot of the last page
   instead of trailing the final clause halfway up it. Zero until then, which
   is also the fallback if the measuring pass never runs. */
.signgap{height:0;}
.signend{display:block;height:0;}
.sg{flex:1;text-align:center;}
.sgl{font-weight:bold;}
.sgline{border-top:1px solid #000;width:120px;margin:18px auto 4px;}
.sgn{font-size:11px;}
/* The footer is painted by a fixed box so it pins to the bottom of EVERY page,
   but a fixed box takes no room in the flow — Chrome happily broke a line into
   the band it occupies and the opaque background then sliced that line in half.
   Clause 23 of the rent contract came out with its second line cut off.

   So the space is reserved separately, by .footspace inside the table's tfoot:
   a table-footer-group repeats on every printed page and DOES occupy flow, so
   text stops short of the band the footer paints into. Its height must stay
   greater than the footer's own (6px padding + ~14px of 9px text + border);
   the surplus is the gap between the last line and the rule. */
.foot{position:fixed;bottom:0;left:0;right:0;padding-top:6px;
  border-top:.8px solid #bbb;display:flex;justify-content:space-between;
  font-size:9px;background:#fff;}
.footspace{height:30px;}
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
    <div class="card"><div class="ct">${esc(T.cardTitle)}</div>${card}</div>
    <div class="chead">${esc(T.clausesHead)}</div>
    ${clausesHtml}
    ${notes}
    <div class="signgap"></div>
    <div class="signs">
      ${sign(T.sign1, c.party1_name)}
      ${sign(T.signAgent, c.agent_name)}
      ${sign(T.sign2, c.party2_name)}
    </div>
    <span class="signend"></span>
  </td></tr></tbody>
  ${footerCells.length ? `<tfoot><tr><td>
    <div class="footspace"></div>
  </td></tr></tfoot>` : ""}
</table>
${attachmentsHtml}
${footerCells.length ? `<div class="foot">${footerCells.map((x) =>
    `<span>${esc(x)}</span>`).join("")}</div>` : ""}
<script>
/*
 * Drops the signatures to the foot of the last page.
 *
 * There is no CSS for "the bottom of whichever page the document ends on" —
 * @page has no :last, and a fixed box would repeat on every page. So the empty
 * space is measured and poured into .signgap.
 *
 * The measurement is a rehearsal, not arithmetic: the content is cloned into a
 * multi-column box the size of the page's text area. Chrome fragments columns
 * with the same engine it fragments pages with — repeating the table's thead
 * and tfoot per fragment exactly as it does per page — so the rehearsal
 * reproduces the real page breaks, including widows and orphans and the slack
 * a page keeps when the next line will not fit. Dividing the content height by
 * the page height does not: it misses that slack, and overshoots by roughly a
 * line per page.
 *
 * Called by the renderer once the real fonts are in place — measuring against
 * fallback metrics would wrap the lines somewhere else entirely.
 */
window.__fitLayout = function () {
  var table = document.querySelector("table.page");
  var cell = document.querySelector("tbody td");
  var gap = document.querySelector(".signgap");
  if (!table || !cell || !gap) return null;

  // The paper's text width (A4 less the side margins), so the rehearsal wraps
  // its lines where the printed page will.
  document.body.style.width = "178mm";

  // A column has to stand for the strip of page the CLAUSES get, not the whole
  // page: the company band and the footer's reserved band repeat on every
  // printed page and take their cut first. Multi-column layout does not repeat
  // a table's header groups the way pagination does, so they are measured off
  // the live table and subtracted instead of being cloned into the rehearsal.
  var probe = document.createElement("div");
  probe.style.cssText = "position:absolute;visibility:hidden;height:259mm;";
  document.body.appendChild(probe);
  var pageH = probe.getBoundingClientRect().height;
  probe.remove();

  var box = function (sel) {
    var el = document.querySelector(sel);
    return el ? el.getBoundingClientRect().height : 0;
  };
  var colH = pageH - box("table.page thead") - box(".footspace");

  var sim = document.createElement("div");
  sim.style.cssText = "position:absolute;left:-20000px;top:0;" +
    "visibility:hidden;width:178mm;height:" + colH + "px;" +
    "column-width:178mm;column-gap:0;column-fill:auto;";
  document.body.appendChild(sim);

  // Lays the clauses out with the given filler and reports where they end.
  function rehearse(px) {
    gap.style.height = px + "px";
    sim.textContent = "";
    for (var n = cell.firstChild; n; n = n.nextSibling) {
      sim.appendChild(n.cloneNode(true));
    }
    var s = sim.getBoundingClientRect();
    var end = sim.querySelector(".signend").getBoundingClientRect();
    return {
      // Columns run right to left, the document being RTL.
      page: Math.round((s.right - end.right) / s.width) + 1,
      // Every column starts at the box's top, so this is the room left below
      // the signatures on the page they landed on.
      room: colH - (end.bottom - s.top),
    };
  }

  var flat = rehearse(0);

  // Binary search for the tallest filler the last page still swallows.
  //
  // Not arithmetic: the filler is not worth its own height, because it starts
  // wherever the last clause left off and part of it goes on finishing that
  // page. And the exact figure is a pixel too tall anyway — the signatures
  // carry a top margin that the measured room below them does not include, so
  // a computed fit lands a hair over and Chrome moves the whole block, margin
  // and all, onto a page of its own. Searching sidesteps both: the fill only
  // ever grows while the signatures stay on the page they started on, so the
  // worst case is the layout we had before.
  var lo = 0;
  // The filler cannot need more than the room below the signatures plus a
  // whole page — nothing follows them but their own end marker.
  var hi = flat.room + colH;
  for (var i = 0; i < 12 && hi - lo > 2; i++) {
    var mid = (lo + hi) / 2;
    if (rehearse(mid).page === flat.page) lo = mid; else hi = mid;
  }
  var applied = Math.floor(lo);
  gap.style.height = applied + "px";
  sim.remove();
  return {pages: flat.page, room: Math.round(flat.room),
    applied: Math.round(applied)};
};
</script>
</body></html>`;
}

module.exports = {buildContractHtml, contractViewModel};
