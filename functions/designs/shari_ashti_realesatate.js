"use strict";
/**
 * Shari Ashti Realesatate.
 *
 * Two things make this company's contract its own, and both come from what
 * they had before this app: the sheets are pre-printed letterhead, and the
 * Windows program they used set its documents in Unikurd Hejar and opened them
 * with the contract number and the date.
 *
 * Deliberately NOT a contractHtml takeover. The shared layout already puts the
 * title first and the parties and property below it; all that was missing was
 * the number-and-date block, which the base now takes from `metaHtml`. So this
 * company still rides the shared document and still gets fixes made to it.
 */

const {hejarFace} = require("./ashti_font");

/**
 * The block the old documents opened with: contract number, then date.
 *
 * Printing it here is why the base drops the number from the info card — see
 * designs/index.js. Everything is run through vm.esc, like any other value on
 * the page: these are document fields, and the digits have to convert with the
 * rest of them.
 *
 * @param {object} vm the contract view model
 * @return {string} markup
 */
const metaHtml = (vm) => `
<div class="ashti-meta">
  <div><b>${vm.esc(vm.label.contractNo)}</b> ${vm.esc(vm.contract.contract_number || "")}</div>
  <div><b>${vm.esc(vm.label.date)}</b> ${vm.esc(vm.dateText)}</div>
</div>`;

/**
 * The info block, laid out the way their Windows program had it: each party on
 * its own line with the phone beside it, and the four property facts one per
 * line rather than run together. No heading and no box — the old forms had
 * neither; the frames on the printout came from the report tool, not the
 * design.
 *
 * @param {object} vm the contract view model
 * @return {string} markup
 */
const cardHtml = (vm) => {
  const e = vm.esc;
  const c = vm.contract;
  const T = vm.label;

  // The party rows carry the phone at the far end of the line, as the old form
  // did — it had its own field over there, not a note trailing the name.
  const party = (label, name, phone) => `
    <div class="a-row a-party">
      <span><span class="a-l">${e(label)}</span> <span class="a-v">${e(name || "")}</span></span>
      ${phone ? `<span class="a-ph">${e(T.phone)} ${e(phone)}</span>` : ""}
    </div>`;

  const parties = vm.isRent ?
    party(T.party1Rent, c.party1_name, c.party1_mobile) +
      party(T.party2Rent, c.party2_name, c.party2_mobile) :
    party(T.party1Sale, c.party1_name, c.party1_mobile) +
      party(T.party2Sale, c.party2_name, c.party2_mobile);

  // One fact per line, in the order the old form listed them: type, number,
  // project, area. The shared pairs run type, project, number, area.
  const [type, project, number, area] = vm.propertyPairs;
  const facts = [type, number, project, area].map(([l, v]) =>
    `<div class="a-row"><span class="a-l">${e(l)}</span> <span class="a-v">${e(v)}</span></div>`
  ).join("");

  return `<div class="a-card">${parties}${facts}</div>`;
};

const css = `
/* Unikurd Hejar, what this company's paperwork has always been set in. Named
   as its own family rather than redefining DocFont, so which face is in use
   is unambiguous rather than depending on declaration order. */
${hejarFace()}
html:not([lang="en"]) body{font-family:'Hejar','DocFont' !important;}
/* Hejar has no Latin letters. The English edition set in it fell back to
   whatever the system had, so English keeps the house Latin face. */

/* Sizes the company asked for: the title at 25, everything else at 14 — in
   POINTS, which is what their old report tool meant by them. Set as px the
   text came out three quarters of the size of the same words on the old
   printout. The body rule carries the 14 so it inherits everywhere, and the
   base rules that set their own size are brought back in line. */
body{font-size:14pt !important;}
.title{font-size:25pt !important;}
.chead, .sgn, .notes{font-size:14pt !important;}

/* --- Where everything sits ---------------------------------------------
   Every figure below reproduces a printout from their old Windows program,
   photographed flat on the letterhead and scaled against the letterhead's own
   landmarks (header rules at 28mm, footer text at 285.6mm). Page 1, measured
   to the middle of each line, in mm from the top of the sheet:

     title 18.7 (in the header band, level with the logo, right-aligned)
     contract no. 39.9 (the first line under the letterhead rules)
     phone column 96mm in from the text's right edge
     clause lines 6.9mm apart; last line ≈ 272, above the footer rule at 280

   The spacing between lines below the number no longer copies the printout:
   the company asked for one even gap throughout (see --gap).

   Header lines sit 6mm in from the clauses' right edge, as they did there.
   A photo is good to a millimetre or two; a test print settles the rest. */

/* One margin for every page, so the renderer's page rehearsal (which assumes
   uniform pages) stays true. 14mm is where page 1's title belongs; pages
   after it still have to clear the letterhead, which the repeating header
   spacer below does. Sides clear the 6.4mm strip on the left. */
@page{margin:14mm 18mm 21mm 22mm;}
/* The rehearsal reads the page height from --page-h and forces the text
   width to 178mm; both have to describe THESE margins or the signatures get
   dropped by the wrong amount. (The earlier 35/16/16 margins never updated
   either, which printed the signatures alone on a page.) */
:root{--page-h:262mm;--text-w:170mm;}

/* The sheet has the logo and company name at the top, and the phones, e-mail
   and address along the foot. Ours would print over theirs. */
.band, .bandline{display:none !important;}
.foot{display:none !important;}
.footspace{height:0 !important;}

/* The watermark is the logo again, faintly, across the middle. On a sheet
   already branded top, bottom and side it reads as a printing fault. */
.watermark{display:none !important;}

/* The table header repeats on every printed page, so a spacer in it pushes
   each page's text below the letterhead rules: 14 + 22.85 = 36.85mm, the top
   of the contract-number line. The rehearsal measures the thead, so this is
   accounted for there too. */
table.page thead td::before{content:"";display:block;height:22.85mm;}

/* The title prints once, up in the header band beside the logo — above the
   spacer, where the flow cannot reach. Absolute against page 1. Physically
   right in every edition, English included: the logo holds the left.

   Everything below uses start/end rather than right/left, so the English
   edition mirrors the layout instead of half-following it. */
.title{position:absolute;top:-0.6mm;right:6mm;margin:0;line-height:1.2;
  text-align:right;font-weight:bold;}

/* Weights. Hejar has no bold cut, so what is bold here is synthesised — and
   until the font declaration was fixed none of it showed at all. The title is
   bold, as the company asked; everything else keeps the single weight their
   paperwork has always printed in, which is what the labels, the clause
   heading and the signature captions had on the sheets they signed off. */
.a-l, .chead, .sgl, .ashti-meta b{font-weight:normal;}

/* One gap everywhere, at the company's request: the same 3.3mm between
   number and date, between the parties, between the property lines, around
   "both parties agree…", and between clauses. The old printout's uneven
   spacing (a wide gap between the two parties, tight property lines) read as
   a mistake on paper. --gap is the one number to change. */
:root{--gap:3.3mm;}

/* Number and date. */
.ashti-meta{margin:0;padding-inline-end:6mm;line-height:6.1mm;}
.ashti-meta div{text-align:start;}
.ashti-meta div + div{margin-top:var(--gap);}
.ashti-meta b{color:inherit;}

/* The info block: plain lines, no heading and no box. */
.a-card{margin:var(--gap) 0 0;padding-inline-end:6mm;line-height:6.1mm;}
.a-row{white-space:nowrap;}
.a-row + .a-row{margin-top:var(--gap);}

/* Party lines: label and name, then the phone in its own column 90mm to the
   left — a fixed column, as on the old form, not pushed to the far edge. The
   name part grows past 90mm rather than overprinting a long name. */
.a-party{display:flex;align-items:baseline;}
.a-party > span:first-child{flex:none;min-width:90mm;}

/* "Both parties agree on the clauses below", 26.7mm in from the start. */
.chead{margin:var(--gap) 0 !important;padding-inline-end:26.7mm;
  text-align:start;line-height:6.1mm;}

.clause{line-height:6.9mm;margin-bottom:var(--gap) !important;}
`;

// The receipt works on a different principle from the contract — values
// dropped onto a pre-printed pad rather than a document we lay out — so it
// lives in its own file.
const {receiptHtml} = require("./shari_ashti_receipt");

module.exports = {css, metaHtml, cardHtml, receiptHtml};
