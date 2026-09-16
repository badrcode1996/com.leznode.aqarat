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
 * measured off a 200dpi scan of the pad.
 *
 * Horizontal positions are CSS `right`, i.e. mm from the RIGHT edge of the
 * sheet. The form is right-to-left: each value starts just left of its Kurdish
 * label and grows leftward, as it would be written by hand. (The first cut
 * took offsets measured from the left and used them as `right`, which put
 * every value over the English labels and swapped the signature names.)
 *
 * Vertical positions are the centre of the label's line, from the top of that
 * voucher's banner; the value is then raised by half its own height so it
 * sits on the line with the label rather than under it.
 *
 * READ THIS BEFORE CHANGING ANYTHING: paper does not feed the same way twice,
 * and a scan is approximate. These numbers are a starting point that WILL need
 * a test print or two. NUDGE is there for exactly that — it shifts every value
 * on the sheet at once, which is almost always what is wrong. Per-field
 * numbers should only be touched if one line alone is off.
 */

const {hejarFace} = require("./ashti_font");

/** Shifts every printed value, in mm. Positive moves down / left. */
const NUDGE = {down: 0, left: 0};

/** Top of each voucher's banner on the sheet, in mm. */
const COPY_TOP = [10.7, 10.7 + 149.2];

/** Half the height of a 14px line, to centre a value on its label's line. */
const HALF_LINE = 1.9;

/**
 * Each field: `line` is the centre of its row, in mm below the voucher top;
 * `right` is where the value ends, in mm from the sheet's right edge (just
 * clear of the Kurdish label); `width` is the dotted span it may fill.
 * Measured on the scan as label edge (mm from the left) → 210 − that − 2.
 */
const FIELD = {
  date: {line: 25.8 - 10.7, right: 40, width: 28},
  branch: {line: 25.8 - 10.7, right: 80, width: 55},
  number: {line: 41.6 - 10.7, right: 48.5, width: 128},
  person: {line: 52.6 - 10.7, right: 65.5, width: 107},
  amount: {line: 63.5 - 10.7, right: 40.5, width: 147},
  purpose: {line: 74.3 - 10.7, right: 35.5, width: 141},
  note: {line: 85.2 - 10.7, right: 32.5, width: 162},
};

/**
 * The three names, centred over the pad's own signature rules (which sit at
 * 122.6mm, captions below). Right to left as printed: accountant, received
 * by, delivered to — column centres 153.6, 103 and 52.5mm from the left.
 */
const SIGN_LINE = 119.5 - 10.7;
const SIGN_WIDTH = 50;
const SIGN_RIGHT = {
  accountant: 210 - 153.6 - SIGN_WIDTH / 2,
  receivedBy: 210 - 103 - SIGN_WIDTH / 2,
  deliveredTo: 210 - 52.5 - SIGN_WIDTH / 2,
};

/**
 * A value, positioned.
 *
 * @param {number} line mm from the page top to the centre of the row
 * @param {string} text already escaped
 * @param {object} opt {right, width, align}
 * @return {string} markup
 */
function at(line, text, opt) {
  const top = line - HALF_LINE + NUDGE.down;
  const right = opt.right - NUDGE.left;
  return `<div class="v" style="top:${top}mm;right:${right}mm;` +
    `width:${opt.width}mm;text-align:${opt.align || "right"}">${text}</div>`;
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

  const field = (top, name, text) =>
    at(top + FIELD[name].line, text, FIELD[name]);
  const sign = (top, who, text) => at(top + SIGN_LINE, text,
      {right: SIGN_RIGHT[who], width: SIGN_WIDTH, align: "center"});

  const voucher = (top) => [
    field(top, "date", e(vm.dateText)),
    field(top, "branch", e(r.branch || "")),
    field(top, "number", e(r.receipt_number || "")),
    field(top, "person", e(r.person_name || "")),
    field(top, "amount", e(vm.amountText)),
    field(top, "purpose", e(r.payment_purpose || "")),
    field(top, "note", e(r.note || "")),
    sign(top, "accountant", e(r.agent_name || "")),
    sign(top, "receivedBy", e(vm.receivedBy || "")),
    sign(top, "deliveredTo", e(vm.deliveredTo || "")),
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
/* line-height 1 makes each box exactly one line tall, which HALF_LINE
   assumes when it centres the value on its row. */
.v{position:absolute;line-height:1;white-space:nowrap;overflow:hidden;}
</style></head><body>
${voucher(COPY_TOP[0])}
${voucher(COPY_TOP[1])}
</body></html>`;
};

module.exports = {receiptHtml};
