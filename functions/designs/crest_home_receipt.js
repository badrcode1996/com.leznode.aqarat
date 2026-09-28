"use strict";
/**
 * Crest Home — the receipt.
 *
 * Built to a voucher the company sent as the look they want: the company name
 * and the voucher's date and number down the right, the logo in the middle
 * over a band naming the kind of voucher, the English name on the left, then
 * the details on dotted rules, two signatures, and a band at the foot with the
 * company and its phones.
 *
 * A full takeover rather than CSS over the shared voucher: the shared one is a
 * form of labelled fields in three languages, and this is a different document
 * — one language, a header in three columns, and its own footer.
 *
 * Two copies to the sheet, as their voucher has, and neither is labelled:
 * theirs are identical.
 *
 * Deliberately NOT on the page, because the app does not hold it:
 *   - the payer's phone number. A receipt records a person's name, not their
 *     contact.
 *   - "بڕی ماوە", the balance left. Nothing in the app tracks a running
 *     balance against a receipt, and a zero printed there would be a claim
 *     about somebody's debt that no data supports.
 *   - the website and e-mail on their footer. The company record carries
 *     phones and an address; the address takes that line instead.
 */

/** The colour comes from the view model, so the app's picker still works. */
const {WORDMARK, NAME_KU} = require("./crest_home_brand");

/**
 * Escapes for the page but leaves the digits as typed. vm.esc rewrites 0-9 as
 * ٠-٩ everywhere, which the company wants for the money but not for the date,
 * the time or the voucher number — those read as figures on their form.
 */
const plain = (s) => String(s == null ? "" : s)
    .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

const receiptHtml = (vm) => {
  const e = vm.esc;
  const r = vm.receipt || {};
  const c = vm.company || {};
  const accent = vm.accent;

  // Who signs which side. On a payment the roles swap: the company pays out,
  // so its agent is the payer and the person is the receiver.
  const payer = vm.isPay ? r.agent_name : r.person_name;
  const receiver = vm.isPay ? r.person_name : r.agent_name;

  // Their voucher stamps the time beside the date.
  const d = r.date instanceof Date ? r.date : new Date(r.date);
  const timeText = isNaN(d.getTime()) ? "" : (() => {
    const h = d.getHours();
    const m = String(d.getMinutes()).padStart(2, "0");
    const am = h < 12 ? "AM" : "PM";
    return `${String(h % 12 || 12).padStart(2, "0")}:${m} ${am}`;
  })();

  // Cropped by the wrapper below — see .logobox in the stylesheet.
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

  // Figure on one side, the same amount in words on the other, as their
  // voucher has it. moneyWords spells the number only, so the currency is
  // named here — "دوازدە هەزار" alone does not say of what.
  const amountInWords = [vm.amountWords, r.currency_label]
      .filter(Boolean).join(" ");

  // The figure names the currency too, which the company asked for: a bare
  // ٥٠٠ on a voucher is not an amount. The short word beside the figure and
  // the full label beside the words, so the line does not say "دیناری
  // عێراقی" twice.
  const SHORT_CURRENCY = {IQD: "دینار", USD: "دۆلار"};
  const amountFigure =
    [vm.money(r.amount), SHORT_CURRENCY[r.currency]].filter(Boolean).join(" ");

  const phones = [c.phone1, c.phone2].filter(Boolean).join("   ");
  const branch = r.branch ? ` / ${r.branch}` : "";

  const voucher = () => `
  <div class="v">
    <div class="head">
      <div class="col right">
        ${NAME_KU.map((l, i) => `<div class="${i ? "cname" : "ctrade"}">${e(l)}</div>`).join("")}
        <div class="meta">${e("بەروار:")} <b class="fig">${plain(vm.dateText)}</b></div>
        ${timeText ? `<div class="meta"><b class="fig">${plain(timeText)}</b></div>` : ""}
        <div class="meta">${e("ژ. پسوولە:")} <b class="fig">${plain(r.receipt_number || "")}</b></div>
      </div>
      <div class="col mid">
        ${logo}
        <div class="band">${e(vm.titleKu)}</div>
      </div>
      <div class="col left">
        ${WORDMARK.map((l) => `<div class="cen">${e(l)}</div>`).join("")}
      </div>
    </div>

    <div class="body">
      ${row(vm.isPay ? "پێدرا بە بەڕێز:" : "وەرمگرت لە بەڕێز:", r.person_name || "")}
      ${row("بڕی پارە:", amountFigure, amountInWords)}
      ${row("لە بری:", r.payment_purpose || "")}
      ${r.note ? row("تێبینی:", r.note) : ""}
    </div>

    <div class="signs">
      ${sign("وەرگر", receiver)}
      ${sign("پارەدەر", payer)}
    </div>

    <div class="foot">
      <span>${e((c.nameKu || "") + branch)}</span>
      ${c.address ? `<span class="addr">${e(c.address)}</span>` : ""}
      <span class="ph">${e(phones)}</span>
    </div>
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

/* --- Header: name and date right, logo and title middle, English left --- */
.head{display:flex;align-items:flex-start;gap:6mm;}
.col{flex:1;}
.right{text-align:right;}
.left{text-align:left;}
.mid{flex:0 0 46mm;text-align:center;}
/* The masthead: the trade on a smaller line above the name, as on their
   voucher. */
.ctrade{font-size:1.15em;font-weight:bold;color:${accent};line-height:1.3;}
.cname{font-size:1.9em;font-weight:bold;color:${accent};line-height:1.25;
  margin-bottom:2mm;}
.meta{font-size:0.92em;line-height:1.7;}
.cen{font-size:1.85em;font-weight:bold;color:${accent};line-height:1.25;
  letter-spacing:0.5px;text-transform:uppercase;}
/* The logo file is mostly empty space: measured on the artwork they sent,
   21.9% of its height is blank above the mark and 26.9% below, which is the
   gap that kept opening between it and the band underneath.
.logobox crops both away, so the band sits against the artwork and the mark
   itself prints bigger for the same space.

   The three figures below are that measurement. If the company ever replaces
   the logo with one trimmed to its artwork, set LOGO_H as the height you want
   and the other two to 0 and 100%.  */
.logobox{height:28.7mm;overflow:hidden;line-height:0;}
.logo{display:block;width:auto;height:56mm;margin:-12.25mm auto 0;}
/* The date, the time and the voucher number keep Latin figures, and stay
   left-to-right so a date does not come apart in a right-to-left line. */
.fig{direction:ltr;unicode-bidi:isolate;font-weight:bold;}
/* The band naming the voucher. The logo above it is cropped to its artwork
   (see .logobox), so this 5mm is the whole gap between the two — asked for
   once the file's own empty space was out of the way. */
.band{margin-top:5mm;background:${accent};color:#fff;font-weight:bold;
  font-size:1.05em;padding:1.4mm 3mm;border-radius:1mm;}

/* --- The details, each on its own dotted rule --------------------------- */
.body{margin-top:6mm;}
.row{display:flex;align-items:flex-end;gap:3mm;margin-bottom:4.5mm;}
.lbl{flex:0 0 28mm;font-weight:bold;text-align:right;}
/* The rule is the cell's own bottom border, so it runs the full width
   whatever the value's length — an empty field still prints its line. */
.val{flex:1;display:flex;justify-content:space-between;gap:4mm;
  border-bottom:1px dotted #999;padding-bottom:1mm;min-height:5mm;}
.v2{color:#333;}

/* --- Signatures --------------------------------------------------------- */
.signs{display:flex;gap:20mm;margin:6mm 6mm 4mm;}
.sg{flex:1;text-align:center;}
/* Room to sign above the caption, as on their voucher. */
.sgline{height:11mm;}
.sgl{font-weight:bold;}
.sgn{font-size:0.92em;color:#333;margin-top:1mm;}

/* --- Foot: the band, and the address under it --------------------------- */
/* margin-top:auto holds the band at the foot of the voucher whatever the
   details above it come to. */
.foot{margin-top:auto;background:${accent};color:#fff;font-size:0.9em;
  font-weight:bold;
  display:flex;justify-content:space-between;align-items:center;gap:6mm;
  padding:1.6mm 4mm;border-radius:1mm;}
.ph{direction:ltr;letter-spacing:0.5px;}
/* In the bar with the rest of the footer, not under it. */
.addr{flex:1;text-align:center;}
</style></head><body>
${voucher()}
${voucher()}
</body></html>`;
};

module.exports = {receiptHtml};
