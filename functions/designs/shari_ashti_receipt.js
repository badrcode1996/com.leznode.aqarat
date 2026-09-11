"use strict";
/**
 * Shari Ashti — the receipt half of their design. Kept in its own file because
 * it works on a completely different principle from the contract: the contract
 * is a document we lay out, this one is values dropped onto a form somebody
 * else printed.
 *
 * Their receipt pad is pre-printed, two vouchers to an A4 sheet, each carrying
 * its own logo, banner, trilingual field labels, signature captions and
 * contact footer. So NOTHING here draws any of that. Every position below is
 * measured off a scan of the pad, at 200dpi:
 *
 *     copy 1 banner   y=84    10.7mm      copy period   1175px = 149.2mm
 *     date rule       y=254   32.3mm      voucher no.   y=336   42.7mm
 *     received from   y=421   53.5mm      amount        y=507   64.4mm
 *     purpose         y=593   75.3mm      note          y=679   86.2mm
 *     signatures      y=965  122.6mm
 *
 * and the writable span between the English label on the left and the
 * Kurdish/Arabic one on the right runs x=210..1310 = 26.7mm..166.4mm.
 *
 * READ THIS BEFORE CHANGING ANYTHING: paper does not feed the same way twice,
 * and a scan is approximate. These numbers are a starting point that WILL need
 * a test print or two. NUDGE is there for exactly that — it shifts every value
 * on the sheet at once, which is almost always what is wrong. Per-field
 * numbers should only be touched if one line alone is off.
 */

const {hejarFace} = require("./ashti_font");

/** Shifts every printed value. Positive moves down / left. Test prints tune this. */
const NUDGE = {down: 0, left: 0};

/** Where the pad's own labels stop and the writable span begins. */
const SPAN = {right: 166.4, width: 139.7};

/** One voucher's rows, in mm from the top of that voucher's own block. */
const ROW = {
  date: 32.3 - 10.7,
  branch: 32.3 - 10.7,
  number: 42.7 - 10.7,
  person: 53.5 - 10.7,
  amount: 64.4 - 10.7,
  purpose: 75.3 - 10.7,
  note: 86.2 - 10.7,
  signatures: 122.6 - 10.7,
};

/** Top of each voucher on the sheet, in mm. */
const COPY_TOP = [10.7, 10.7 + 149.2];

/** The date line carries the branch too, further left. */
const BRANCH_RIGHT = 100;

/**
 * A value, positioned. Right-aligned because the form is right-to-left: the
 * text grows leftward from the label, exactly as it would be written by hand.
 *
 * @param {number} top mm from the page top
 * @param {string} text already escaped
 * @param {object} [opt] {right, width, align}
 * @return {string} markup
 */
function at(top, text, opt) {
  const o = opt || {};
  const right = (o.right || SPAN.right) + NUDGE.left;
  const width = o.width || SPAN.width;
  return `<div class="v" style="top:${top + NUDGE.down}mm;right:${right}mm;` +
    `width:${width}mm;text-align:${o.align || "right"}">${text}</div>`;
}

/**
 * The whole sheet: two vouchers' worth of values and nothing else.
 *
 * @param {object} vm the receipt view model from receipt_html.js
 * @param {object} o the untouched input
 * @return {string} the page HTML
 */
const receiptHtml = (vm) => {
  const e = vm.esc;
  const r = vm.receipt || {};

  const voucher = (top) => [
    at(top + ROW.date, e(vm.dateText)),
    at(top + ROW.branch, e(r.branch || ""), {right: BRANCH_RIGHT, width: 55}),
    at(top + ROW.number, e(r.receipt_number || "")),
    at(top + ROW.person, e(r.person_name || "")),
    at(top + ROW.amount, e(vm.amountText)),
    at(top + ROW.purpose, e(r.payment_purpose || "")),
    at(top + ROW.note, e(r.note || ""), {}),
    // The three names under the pad's own signature captions, in its order:
    // accountant on the right, then received by, then delivered to.
    at(top + ROW.signatures, e(r.agent_name || ""), {right: 118, width: 45, align: "center"}),
    at(top + ROW.signatures, e(vm.receivedBy || ""), {right: 68, width: 45, align: "center"}),
    at(top + ROW.signatures, e(vm.deliveredTo || ""), {right: 18, width: 45, align: "center"}),
  ].join("");

  return `<!doctype html><html lang="ckb" dir="rtl"><head><meta charset="utf-8">
<style>
/* Unikurd Hejar here too. The values printed onto the pad have to look like
   the labels already on it, which the old Windows program set in this face. */
${hejarFace()}
*{box-sizing:border-box;margin:0;padding:0;}
/* No margin: every value is positioned from the page edge, because that is
   what the pre-printed form is aligned to. */
@page{size:A4;margin:0;}
body{font-family:'Hejar';direction:rtl;font-size:14px;color:#000;
  position:relative;width:210mm;height:297mm;}
/* Each value sits on the pad's own dotted rule. bottom-anchored line height so
   the text rests ON the rule rather than straddling it. */
.v{position:absolute;line-height:1;white-space:nowrap;overflow:hidden;}
</style></head><body>
${voucher(COPY_TOP[0])}
${voucher(COPY_TOP[1])}
</body></html>`;
};

module.exports = {receiptHtml};
