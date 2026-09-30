"use strict";
/**
 * The house design — what every company gets unless it has one of its own.
 *
 * Laid out like Crest Home's paperwork, which is the arrangement the product
 * settled on: a three-column letterhead (the company's names, the logo, the
 * English name), a line carrying the date, the title and the number, the
 * parties and the property in two columns, a solid band introducing the
 * clauses, and a bar at the foot of every page with the phones and address.
 * The voucher opens the same way, so a company's two documents match.
 *
 * What it is NOT is a copy of that company's file. Two things there are
 * theirs alone and are deliberately absent here:
 *   - their wordmark and Kurdish name, written into the design. Here both
 *     come from the company record, because every company has its own.
 *   - the logo crop. Theirs is clipped to the artwork by figures measured off
 *     their file; every company uploads a different one, so the logo is fitted
 *     to its box instead of cropped, which is right for any file.
 *
 * Structured as CSS plus the four block hooks rather than a contractHtml
 * takeover, so the shared layout — and every fix to it, including the pass
 * that keeps the signatures on the foot of the last page — still applies.
 */

const {NAVY, GOLD, ink} = require("./house_brand");

/**
 * The letterhead: the company's names on one side, the logo in the middle,
 * its English name on the other. The English name is pulled out of the name
 * list so it is not printed twice.
 *
 * @param {object} vm the contract view model
 * @param {object} parts {logo} the logo markup, already a data: URI
 * @return {string} markup
 */
const bandHtml = (vm, parts) => {
  const e = vm.esc;
  const en = (vm.company || {}).nameEn || "";
  const rest = vm.names.filter((n) => n !== en);
  return `
  <div class="hs-name">
    ${rest.map((l, i) =>
    `<div class="${i ? "hs-n2" : "hs-n1"}">${e(l)}</div>`).join("")}
  </div>
  <div class="hs-logo">${parts.logo}</div>
  <div class="hs-mark">${en ? `<div class="hs-m1">${e(en)}</div>` : ""}</div>`;
};

/**
 * The line the contract opens with: the date on one side, the title in the
 * middle, the contract number on the other. The shared title block above it
 * is hidden by the stylesheet, so the page still has exactly one title.
 *
 * @param {object} vm the contract view model
 * @return {string} markup
 */
const metaHtml = (vm) => `
<div class="hs-meta">
  <span class="hs-date"><b>${vm.esc(vm.label.date)}</b> ${vm.esc(vm.dateText)}</span>
  <span class="hs-title">(${vm.esc(vm.title)})</span>
  <span class="hs-no"><b>${vm.esc(vm.label.contractNo)}</b> ${vm.esc(vm.contract.contract_number || "")}</span>
</div>`;

/**
 * Parties and property, two to a line: first party beside second party, then
 * the property facts paired off.
 *
 * @param {object} vm the contract view model
 * @return {string} markup
 */
const cardHtml = (vm) => {
  const e = vm.esc;
  const c = vm.contract;
  const T = vm.label;

  const cell = (label, value) =>
    `<div class="hs-cell"><span class="hs-l">${e(label)}</span> ` +
    `<span class="hs-v">${e(value || "")}</span></div>`;

  const parties = vm.isRent ?
    [[T.party1Rent, c.party1_name], [T.party2Rent, c.party2_name]] :
    [[T.party1Sale, c.party1_name], [T.party2Sale, c.party2_name]];

  // propertyPairs runs type, project, number, area — paired here as place
  // with kind, then number with area.
  const [type, project, number, area] = vm.propertyPairs;

  return `<div class="hs-card">` +
    [parties[0], parties[1], project, type, number, area]
        .map(([l, v]) => cell(l, v)).join("") +
    `</div>`;
};

/**
 * The bar at the foot of every page: the phones on one side, the address on
 * the other. It goes in the table's foot rather than the shared fixed box, so
 * it is exactly as wide as the clause band above it — only the flow can
 * promise that. A company with neither phone nor address prints no bar.
 *
 * @param {object} vm the contract view model
 * @return {string} markup
 */
const footHtml = (vm) => {
  const c = vm.company || {};
  const phones = [c.phone1, c.phone2].filter(Boolean).join("   /   ");
  if (!phones && !c.address) return "";
  return `<div class="hs-foot">
    <span class="hs-ph">${vm.esc(phones)}</span>
    <span>${vm.esc(c.address || "")}</span>
  </div>`;
};

/**
 * The stylesheet. A function, not a string, because the bands print in the
 * company's own colour when it picked one — see ink().
 *
 * @param {object} vm the contract view model
 * @return {string} CSS
 */
const css = (vm) => {
  const C = ink(vm && vm.accent);
  return `
body{color:#1A1A1A;}

/* The signatures sit under the last clauses rather than on a page of their
   own — three clauses is enough of a tail to carry them. */
:root{--min-tail:3;}

/* --- Letterhead ------------------------------------------------------- */
/* Three columns: the company's names, the logo, its English name. Written by
   bandHtml rather than styled out of the shared band, which stacks the names
   beside the logo. */
.band{display:flex;align-items:center;justify-content:space-between;
  gap:6mm;padding:0 0 1mm;}
.hs-name{flex:1;text-align:right;}
.hs-mark{flex:1;text-align:left;}
/* The English edition puts its English name on the leading edge and the
   company's own names on the trailing one — the mirror of the Kurdish and
   Arabic pages, where the name in the reader's language leads. Reversing the
   row does it, so each column keeps the alignment it already has. */
html[dir="ltr"] .band{flex-direction:row-reverse;}
.hs-n1{font-size:19pt;font-weight:bold;color:${C};line-height:1.25;}
.hs-n2{font-size:12pt;font-weight:bold;color:${C};line-height:1.35;}
.hs-m1{font-size:15pt;font-weight:bold;color:${C};line-height:1.3;
  letter-spacing:0.5px;text-transform:uppercase;}

/* Fitted, not cropped: every company uploads its own file and we do not know
   where its artwork sits in it, so the mark is contained in the box whatever
   its proportions. The band repeats in the table's head, so this height is
   paid for on every page — which is why it is height, not width, that is
   kept short here. */
.hs-logo{flex:0 0 auto;height:24mm;line-height:0;}
.band .logo{display:block;width:auto;max-width:55mm;height:24mm;
  object-fit:contain;margin:0;}

/* The rule under the letterhead, in the logo's gold. */
.bandline{border-bottom:1.5px solid ${GOLD};margin:0 0 4mm;}

/* --- Date · title · number -------------------------------------------- */
.title{display:none !important;}
.hs-meta{display:flex;justify-content:space-between;align-items:baseline;
  margin:0 0 5mm;}
.hs-title{font-size:1.2em;font-weight:bold;color:${C};}

/* --- Parties and property --------------------------------------------- */
/* Two columns, reading right to left in Kurdish and Arabic and left to right
   in English, which grid handles on its own. */
.hs-card{display:grid;grid-template-columns:1fr 1fr;gap:3mm 8mm;
  margin:0 0 6mm;}
/* A long name wraps onto a second line rather than being cut off with an
   ellipsis: a party to a contract has to be named in full. */
.hs-cell{line-height:1.5;}
.hs-l{font-weight:bold;color:${C};white-space:nowrap;}

/* --- The clauses ------------------------------------------------------- */
/* A band across the page, with the gold on its leading edge. The logical
   property flips that edge with the language, so it is at the start of the
   line in all three editions. */
.chead{background:${C};color:#fff;font-size:1em !important;font-weight:bold;
  text-align:center;padding:1.6mm 6mm;border-radius:1mm;
  border-inline-start:2mm solid ${GOLD};margin:0 0 4mm !important;}

/* The number hangs in the margin beside the clause, which gives the page its
   column of numerals down the edge. */
.clause{line-height:1.75;margin-bottom:3.5mm !important;
  padding-inline-start:9mm;text-indent:-9mm;}

.notes{margin-top:6mm;}

/* --- Signatures -------------------------------------------------------- */
.signs{gap:8mm;margin-top:16mm;}
.sgl{font-weight:bold;color:${C};}
.sgline{border-top:1px solid ${C};width:55mm;margin:14mm auto 3mm;}
.sgn{font-size:0.9em !important;}

/* --- Footer ------------------------------------------------------------ */
/* Matches the clause band above it — same colour, same padding, same gold
   edge — because the two read as a pair top and bottom of the page. It sits
   in the table's foot, so it is the width of the text column. */
.hs-foot{background:${C};color:#fff;border-radius:1mm;
  border-inline-start:2mm solid ${GOLD};
  padding:1.6mm 6mm;margin-top:6mm;display:flex;
  justify-content:space-between;align-items:center;gap:6mm;
  font-weight:bold;}
/* The phone numbers read left to right whatever the page does. */
.hs-ph{direction:ltr;letter-spacing:0.5px;}

/* Nothing to reserve: the bar above is part of the flow, not a fixed box
   painted over the text. */
.footspace{height:0 !important;}
`;
};

// The voucher is a different document — one language, its own header and
// footer — so it is laid out in full rather than styled over the shared one.
const {receiptHtml} = require("./house_receipt");

module.exports = {css, receiptHtml, receiptAccent: NAVY,
  bandHtml, footHtml, metaHtml, cardHtml, NAVY, GOLD, ink};
