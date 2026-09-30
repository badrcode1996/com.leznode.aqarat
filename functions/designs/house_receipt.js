"use strict";
/**
 * The house voucher — what every company gets unless it has one of its own.
 *
 * Laid out like the contract it is handed over with (see house.js): the
 * company name and the voucher's date and number down one side, the logo in
 * the middle over a band naming the kind of voucher, the English name on the
 * other side, then the details on dotted rules, the signatures, and a bar at
 * the foot with the company, its address and its phones.
 *
 * A full takeover rather than CSS over the shared voucher, because the shared
 * one is a different document: a form of labelled fields in a header strip
 * with an arrow, where this is a letterhead in three columns.
 *
 * What it keeps from the shared voucher, and Crest Home's does not:
 *   - the labels in Kurdish and Arabic both, which is what a form used across
 *     the Region has to do.
 *   - three signatures, including the accountant's. Companies sign these.
 *   - the two copies named — the company's and the client's.
 *   - the branch, which the shared voucher prints as a field.
 */

const {GOLD, ink} = require("./house_brand");

/**
 * Escapes for the page but leaves the digits as typed. vm.esc rewrites 0-9 as
 * ٠-٩ everywhere, which reads well for the money but not for the date, the
 * time or the voucher number — those are references, and are read as figures.
 *
 * @param {*} s any value
 * @return {string} escaped text
 */
const plain = (s) => String(s == null ? "" : s)
    .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

/** The currency named beside the figure — short, because the line is short. */
const SHORT_CURRENCY = {IQD: "دینار", USD: "دۆلار"};

const receiptHtml = (vm) => {
  const e = vm.esc;
  const r = vm.receipt || {};
  const c = vm.company || {};
  const C = ink(vm.accent);

  // Who signs which side. On a payment the roles swap: the company pays out,
  // so its agent is the payer and the person is the receiver.
  const payer = vm.isPay ? r.agent_name : r.person_name;
  const receiver = vm.isPay ? r.person_name : r.agent_name;

  // The time beside the date, as a counter voucher carries it.
  const d = r.date instanceof Date ? r.date : new Date(r.date);
  const timeText = isNaN(d.getTime()) ? "" : (() => {
    const h = d.getHours();
    const m = String(d.getMinutes()).padStart(2, "0");
    const am = h < 12 ? "AM" : "PM";
    return `${String(h % 12 || 12).padStart(2, "0")}:${m} ${am}`;
  })();

  // Fitted to its box, not cropped: every company uploads its own file, so
  // there is no knowing where the artwork sits inside it.
  const logo = vm.logoUri ?
    `<div class="logobox"><img class="logo" src="${vm.logoUri}"></div>` : "";

  // A row of the body: label, then the value on a dotted rule. `second` is
  // the figure's twin — the amount spelled out — which sits to its left.
  const row = (label, value, second) => `
    <div class="row">
      <span class="lbl">${e(label)}</span>
      <span class="val">
        <span class="v1">${e(value)}</span>
        ${second ? `<span class="v2">${e(second)}</span>` : ""}
      </span>
    </div>`;

  const sign = (label, name) => `
    <div class="sg">
      <div class="sgline"></div>
      <div class="sgl">${e(label)}</div>
      <div class="sgn">${e(name || "")}</div>
    </div>`;

  // Figure on one side, the same amount in words on the other. moneyWords
  // spells the number only, so the currency is named here — "دوازدە هەزار"
  // alone does not say of what.
  const amountInWords = [vm.amountWords, r.currency_label]
      .filter(Boolean).join(" ");
  // The figure names its currency too: a bare ٥٠٠ on a voucher is not an
  // amount. The short word beside the figure and the full label beside the
  // words, so the line does not say "دیناری عێراقی" twice.
  const amountFigure =
    [vm.money(r.amount), SHORT_CURRENCY[r.currency]].filter(Boolean).join(" ");

  const phones = [c.phone1, c.phone2].filter(Boolean).join("   ");
  const branch = r.branch ? ` / ${r.branch}` : "";
  // The name in the foot bar: the Kurdish one, or whatever the company has.
  const footName = (c.nameKu || c.nameAr || c.nameEn || "") + branch;

  // The letterhead names: everything but the English name on one side, the
  // English name on the other, so neither is printed twice.
  const nameLines = [c.nameKu, c.nameAr].filter(Boolean);

  const voucher = (copyLabel) => `
  <div class="v">
    <div class="head">
      <div class="col right">
        ${nameLines.map((l, i) =>
    `<div class="${i ? "ctrade" : "cname"}">${e(l)}</div>`).join("")}
        <div class="meta">${e("بەروار / التأريخ:")} <b class="fig">${plain(vm.dateText)}</b></div>
        ${timeText ? `<div class="meta"><b class="fig">${plain(timeText)}</b></div>` : ""}
        <div class="meta">${e("ژ. پسوولە / رقم الوصل:")} <b class="fig">${plain(r.receipt_number || "")}</b></div>
      </div>
      <div class="col mid">
        ${logo}
        <div class="band">
          <div>${e(vm.titleKu)}</div>
          <div class="sub">${e(vm.titleAr)}</div>
        </div>
      </div>
      <div class="col left">
        ${c.nameEn ? `<div class="cen">${e(c.nameEn)}</div>` : ""}
        <div class="copy">${e(copyLabel)}</div>
      </div>
    </div>

    <div class="body">
      ${row(vm.isPay ? "پێدرا بە بەڕێز / دُفِع إلى:" : "وەرمگرت لە بەڕێز / استلمت من:",
    r.person_name || "")}
      ${row("بڕی پارە / مبلغ وقدره:", amountFigure, amountInWords)}
      ${row("لە بری / وذلك لقاء:", r.payment_purpose || "")}
      ${r.note ? row("تێبینی / ملاحظة:", r.note) : ""}
    </div>

    <div class="signs">
      ${sign("کارمەندی بەرپرس / المحاسب", r.agent_name)}
      ${sign("پێدەر / المسلّم", payer)}
      ${sign("وەرگر / المستلم", receiver)}
    </div>

    ${footName || phones || c.address ? `<div class="foot">
      <span>${e(footName)}</span>
      ${c.address ? `<span class="addr">${e(c.address)}</span>` : ""}
      <span class="ph">${e(phones)}</span>
    </div>` : ""}
  </div>`;

  return `<!doctype html><html lang="ckb" dir="rtl"><head><meta charset="utf-8">
<style>
@font-face{font-family:'Speda';src:url(data:font/ttf;base64,${vm.fontRegB64}) format('truetype');font-weight:normal;}
@font-face{font-family:'Speda';src:url(data:font/ttf;base64,${vm.fontBoldB64}) format('truetype');font-weight:bold;}
*{box-sizing:border-box;margin:0;padding:0;}
@page{size:A4;margin:0;}
body{font-family:'Speda';direction:rtl;color:#1A1A1A;font-size:${vm.fontSize};}

/* Two to the sheet, each half of it, with the fold between them. */
.v{height:148.5mm;padding:10mm 12mm 6mm;display:flex;flex-direction:column;}
.v + .v{border-top:1px dashed #BBB;}

/* --- Header: names and date right, logo and title middle, English left -- */
.head{display:flex;align-items:flex-start;gap:6mm;}
.col{flex:1;}
.right{text-align:right;}
.left{text-align:left;}
.mid{flex:0 0 46mm;text-align:center;}
.cname{font-size:1.7em;font-weight:bold;color:${C};line-height:1.25;}
.ctrade{font-size:1.05em;font-weight:bold;color:${C};line-height:1.35;}
.right .meta:first-of-type{margin-top:2mm;}
.meta{font-size:0.92em;line-height:1.7;}
.cen{font-size:1.5em;font-weight:bold;color:${C};line-height:1.25;
  letter-spacing:0.5px;text-transform:uppercase;}
/* Which of the two copies this is — the company's or the client's. */
.copy{margin-top:2mm;font-size:0.85em;font-weight:bold;color:#555;}
/* Fitted, not cropped. A tall logo and a wide one both keep their shape. */
.logobox{height:26mm;line-height:0;}
.logo{display:block;width:auto;max-width:46mm;height:26mm;margin:0 auto;
  object-fit:contain;}
/* The date, the time and the voucher number keep Latin figures, and stay
   left-to-right so a date does not come apart in a right-to-left line. */
.fig{direction:ltr;unicode-bidi:isolate;font-weight:bold;}
/* The band naming the voucher, with the logo's gold on its leading edge —
   the same pair the contract's clause band and footer print in. */
.band{margin-top:4mm;background:${C};color:#fff;font-weight:bold;
  border-inline-start:1.5mm solid ${GOLD};
  padding:1.2mm 3mm;border-radius:1mm;line-height:1.35;}
.band .sub{font-size:0.82em;font-weight:normal;}

/* --- The details, each on its own dotted rule --------------------------- */
.body{margin-top:5mm;}
.row{display:flex;align-items:flex-end;gap:3mm;margin-bottom:4mm;}
.lbl{flex:0 0 48mm;font-weight:bold;text-align:right;color:${C};}
/* The rule is the cell's own bottom border, so it runs the full width
   whatever the value's length — an empty field still prints its line. */
.val{flex:1;display:flex;justify-content:space-between;gap:4mm;
  border-bottom:1px dotted #999;padding-bottom:1mm;min-height:5mm;}
.v2{color:#333;}

/* --- Signatures --------------------------------------------------------- */
.signs{display:flex;gap:10mm;margin:5mm 4mm 4mm;}
.sg{flex:1;text-align:center;}
/* Room to sign above the caption. */
.sgline{height:10mm;}
.sgl{font-weight:bold;font-size:0.9em;}
.sgn{font-size:0.88em;color:#333;margin-top:1mm;}

/* --- Foot: the bar with the company, its address and its phones --------- */
/* margin-top:auto holds the bar at the foot of the voucher whatever the
   details above it come to. */
.foot{margin-top:auto;background:${C};color:#fff;font-size:0.9em;
  font-weight:bold;border-inline-start:1.5mm solid ${GOLD};
  display:flex;justify-content:space-between;align-items:center;gap:6mm;
  padding:1.6mm 4mm;border-radius:1mm;}
.ph{direction:ltr;letter-spacing:0.5px;}
/* In the bar with the rest of the footer, not under it. */
.addr{flex:1;text-align:center;}
</style></head><body>
${voucher("کۆپی کۆمپانیا")}
${voucher("کۆپی زەبوون")}
</body></html>`;
};

module.exports = {receiptHtml};
