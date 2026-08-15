"use strict";

/**
 * Builds the receipt (وەصڵ/پسولە) voucher HTML — two copies on one A4 page —
 * rendered to PDF by headless Chrome so Kurdish/Arabic shaping (especially ێ)
 * is correct. The banner title and signature captions are trilingual; the
 * per-field labels are Kurdish/Arabic only.
 */

const {resolveDesign} = require("./designs");

const TYPE = {
  external_receive: ["پسولەی پارە وەرگرتن", "وصل قبض", "RECEIPT VOUCHER", false],
  external_pay: ["پسولەی پارەدان", "وصل صرف", "PAYMENT VOUCHER", true],
  rent_receive: ["پسولەی وەرگرتنی کرێ", "وصل قبض الإيجار", "RENT RECEIPT", false],
  rent_pay: ["پسولەی دانەوەی کرێ", "وصل صرف الإيجار", "RENT PAYMENT", true],
};

const escAttr = (s) => esc(s).replace(/"/g, "&quot;");

const esc = (s) =>
  String(s == null ? "" : s)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");

const money = (n) =>
  Number(n || 0).toLocaleString("en-US");

function fmtDate(d) {
  const dt = d instanceof Date ? d : new Date(d);
  const y = dt.getFullYear();
  const m = String(dt.getMonth() + 1).padStart(2, "0");
  const day = String(dt.getDate()).padStart(2, "0");
  return `${y}/${m}/${day}`;
}

/**
 * @param {object} o data: {receipt, company, template, fontRegB64, fontBoldB64}
 * @return {string} full HTML document
 */
/**
 * Prepared receipt values for a per-company layout in designs/ — the money
 * direction, the trilingual labels and the formatted date resolved once, so a
 * bespoke design only writes markup. See designs/index.js.
 *
 * @param {object} o {receipt, company, template, fontRegB64, fontBoldB64,
 *   companyId}
 * @return {object} prepared values
 */
function receiptViewModel(o) {
  const r = o.receipt || {};
  const c = o.company || {};
  const t = o.template || {};
  const ty = TYPE[r.type] || TYPE.external_receive;
  const isPay = ty[3];

  return {
    receipt: r,
    company: c,
    template: t,
    /** true when money leaves the company (پارەدان). */
    isPay,
    accent: "#" + (t.receipt_color || "1E4D8B"),
    // +2 across the board, not a new default: the stored size was set when the
    // voucher printed smaller than it reads on paper, so every company's
    // setting — default or customised — is two points short of legible.
    fontSize: ((t.receipt_font_size || 10) + 2) + "px",
    /** Voucher title in Kurdish / Arabic / English. */
    titleKu: ty[0],
    titleAr: ty[1],
    titleEn: ty[2],
    personLabelKuAr: isPay ?
      "پێدرا بە بەڕێز / دُفِع إلى السید/ة" :
      "وەرمگرت لە بەڕێز / استلمت من السید/ة",
    receivedBy: isPay ? r.agent_name : r.person_name,
    deliveredTo: isPay ? r.person_name : r.agent_name,
    dateText: fmtDate(r.date),
    amountText: money(r.amount) + " " + (r.currency_label || ""),
    logoUri: c.logo_data_uri || "",
    footerCells: [c.phone1, c.phone2, c.address].filter(Boolean),
    fontRegB64: o.fontRegB64,
    fontBoldB64: o.fontBoldB64,
    esc, money, fmtDate,
  };
}

function buildReceiptHtml(o) {
  const r = o.receipt || {};
  const c = o.company || {};
  const t = o.template || {};
  // Per-company design — see designs/index.js.
  const design = resolveDesign(o.companyId);
  const vm = receiptViewModel(o);
  if (typeof design.receiptHtml === "function") {
    return design.receiptHtml(vm, o);
  }

  const {accent, isPay, receivedBy, deliveredTo, footerCells} = vm;
  const fs = vm.fontSize;
  const personKuAr = vm.personLabelKuAr;
  const ty = [vm.titleKu, vm.titleAr, vm.titleEn];

  const phones = [c.phone1, c.phone2].filter(Boolean).join(" / ");

  const field = (kuAr, val, opts) => {
    opts = opts || {};
    const labelColor = opts.red ? "#D64545" : "#0F2C59";
    return `<div class="field">
      <div class="kuar" style="color:${labelColor}">${esc(kuAr)} :</div>
      <div class="val">${esc(val)}</div>
    </div>`;
  };

  const sign = (kuAr, en, name) => `<div class="sign">
      <div class="signname">${esc(name)}</div>
      <div class="signline"></div>
      <div class="signku">${esc(kuAr)}</div>
      <div class="signen">${esc(en)}</div>
    </div>`;

  const logo = c.logo_data_uri
    ? `<img class="logo" src="${escAttr(c.logo_data_uri)}">`
    : `<div class="logo logotext">LOGO</div>`;

  const copy = (copyLabel) => `<div class="copy">
    <div class="header">
      <div class="banner" style="background:${accent}">
        <span class="b">${esc(ty[0])}</span>
        <span class="b">${esc(ty[1])}</span>
        <span class="b en3">${esc(ty[2])}</span>
      </div>
      <div class="arrow" style="background:${accent}"></div>
      ${logo}
    </div>
    <div class="copylabel">${esc(copyLabel)}</div>
    <div class="row2">
      ${field("التأريخ / بەروار / DATE", fmtDate(r.date))}
      <div class="sp"></div>
      ${field("لق", r.branch)}
    </div>
    ${field("ژمارەی پسوله / رقم الوصل", r.receipt_number)}
    ${field(personKuAr, r.person_name)}
    ${field("بڕی پارە / مبلغ وقدره",
      money(r.amount) + " " + (r.currency_label || ""))}
    ${field("لەبڕی / وذلك لقاء", r.payment_purpose)}
    ${field("تێبینی / ملاحظة", r.note, {red: true})}
    <div class="spacer"></div>
    <div class="signs">
      ${sign("کارمەندی بەرپرس / المحاسب", "Acountant", r.agent_name)}
      ${sign("لێوەرگیراو / المستلم", "Received From", receivedBy)}
      ${sign("پێدراو / تسلیم الی", "Delivered To", deliveredTo)}
    </div>
    ${footerCells.length ? `<div class="footer" style="background:${accent}">
      ${footerCells.map((x) => `<span>${esc(x)}</span>`)
      .join('<span class="sep"></span>')}
    </div>` : ""}
  </div>`;

  return `<!doctype html><html lang="ckb"><head><meta charset="utf-8">
<style>
@font-face{font-family:'Speda';src:url(data:font/ttf;base64,${o.fontRegB64}) format('truetype');font-weight:normal;}
@font-face{font-family:'Speda';src:url(data:font/ttf;base64,${o.fontBoldB64}) format('truetype');font-weight:bold;}
*{box-sizing:border-box;margin:0;padding:0;}
@page{size:A4;margin:14mm 12mm;}
body{font-family:'Speda';direction:rtl;color:#111;font-size:${fs};}
/* Each copy takes exactly half the printable height (A4 297mm − 14mm×2
   margins = 269mm; half ≈ 134mm) so the second copy begins right at the
   page's vertical centre, on the dashed cut line. */
.copy{display:flex;flex-direction:column;height:134mm;
  padding-bottom:5mm;border-bottom:1.5px dashed #bbb;}
.copy:last-child{border-bottom:none;}
.header{display:flex;align-items:center;gap:0;}
.banner{flex:1;height:34px;border-radius:6px 0 0 6px;color:#fff;
  display:flex;justify-content:space-between;align-items:center;padding:0 14px;}
.banner .b{font-weight:bold;font-size:12px;}
.banner .en3{font-size:10px;}
.arrow{width:16px;height:34px;clip-path:polygon(100% 0,100% 100%,0 50%);}
.logo{width:64px;height:44px;margin-right:10px;display:flex;align-items:center;
  justify-content:center;object-fit:contain;}
.logotext{font-weight:bold;font-size:16px;color:#0F2C59;}
.copylabel{text-align:right;font-weight:bold;color:#0F2C59;font-size:11px;
  margin:4px 4px 4px 0;}
.row2{display:flex;align-items:flex-end;}
.row2 .field{flex:1;}
.row2 .field:first-child{flex:3;}
.row2 .field:last-child{flex:2;}
.sp{width:16px;}
/* .copy is a flex column, so these margins do NOT collapse — the gap between
   two rows is twice this value. 9px keeps the rows comfortably apart at 18px
   without the sparse look 14px (28px apart) gave. The slack goes to .spacer,
   which pushes the signatures to the bottom of the half-page either way. */
.field{display:flex;align-items:flex-end;margin:9px 0;gap:6px;}
.field .kuar{font-weight:bold;white-space:nowrap;}
.field .val{flex:1;border-bottom:1px dotted #888;min-height:1.3em;
  padding:0 4px 1px;}
.spacer{flex:1;}
.signs{display:flex;gap:10px;margin-top:10px;}
.sign{flex:1;text-align:center;}
.signname{font-size:9px;min-height:1.1em;}
.signline{border-top:1px dotted #888;margin:2px 14px 3px;}
.signku{font-weight:bold;font-size:9px;}
.signen{font-weight:bold;font-size:9px;color:#0F2C59;}
.footer{height:24px;border-radius:6px;color:#fff;font-size:8px;
  display:flex;align-items:center;justify-content:space-between;
  padding:0 14px;margin-top:8px;}
.footer .sep{width:1px;height:12px;background:rgba(255,255,255,.4);}
${design.css || ""}
</style></head><body>
${copy("کۆپی کۆمپانیا")}
${copy("کۆپی زەبوون")}
</body></html>`;
}

module.exports = {buildReceiptHtml, receiptViewModel};
