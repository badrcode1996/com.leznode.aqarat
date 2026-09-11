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
  <div><b>${vm.esc("بەروار:")}</b> ${vm.esc(vm.dateText)}</div>
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

  // One fact per line, in the order the old form listed them.
  const facts = vm.propertyPairs.map(([l, v]) =>
    `<div class="a-row"><span class="a-l">${e(l)}</span> <span class="a-v">${e(v)}</span></div>`
  ).join("");

  return `<div class="a-card">${parties}${facts}</div>`;
};

const css = `
/* Unikurd Hejar, what this company's paperwork has always been set in. Named
   as its own family rather than redefining DocFont, so which face is in use
   is unambiguous rather than depending on declaration order. */
${hejarFace()}
body{font-family:'Hejar','DocFont' !important;}

/* Sizes the company asked for: the title at 25, everything else at 14.
   The body rule carries the 14 so it inherits everywhere, and the handful of
   base rules that set their own size are brought back in line — otherwise the
   clause heading and the signature captions would stay at 12 and 11 and read
   as a different document from the body above them. */
body{font-size:14px !important;}
.title{font-size:25px !important;}
.chead, .sgn, .notes{font-size:14px !important;}

/* --- The pre-printed letterhead ---------------------------------------
   The sheet already carries the ASHTI branding, so the document adds nothing
   to those areas and keeps off them. Measured from a scan of the sheet:
     left edge   a dark ASHTI strip, 3.07% of the width  = 6.4mm on A4
     top         the logo and two rules, down to 10.2%   = 30.3mm
     bottom      rules, an arc and the contact details,
                 from 96.2% down                          = 11.3mm
   The margins below are those numbers plus a few mm, because a scan is
   approximate and sheet feeding is not exact. If a test print still lands on
   the letterhead, these are the values to change. The sides keep the base
   16mm, which already clears the 6.4mm strip. */
@page{margin:35mm 16mm 16mm;}

/* The sheet has the logo and company name at the top, and the phones, e-mail
   and address along the foot. Ours would print over theirs. */
.band, .bandline{display:none !important;}
.foot{display:none !important;}
.footspace{height:0 !important;}

/* The watermark is the logo again, faintly, across the middle. On a sheet
   already branded top, bottom and side it reads as a printing fault. */
.watermark{display:none !important;}

/* The title is now the first thing on the page. */
.title{margin-top:0;}

/* Number and date, the way the old documents opened. Right-aligned under the
   title, which is where they sat on the printed forms.

   Line spacing is the thing that makes this read like the old paperwork. That
   was set tight — about 1.3 — and the shared document's 2.0 spread the same
   six lines over nearly twice the depth, which is what "hiç wekû yek nîn"
   was pointing at. */
.ashti-meta{margin:2px 0 6px;line-height:1.35;}
.ashti-meta div{text-align:right;}
.ashti-meta b{color:inherit;}

/* The info block: plain lines, no heading and no box. The old forms had
   neither — the frames on that printout came from the report tool. */
.a-card{margin:2px 0 8px;line-height:1.35;}
.a-row{white-space:nowrap;}
.a-l{font-weight:bold;}

/* A party line runs label+name at the start and the phone at the far end,
   which is where its own field sat on the old form. */
.a-party{display:flex;justify-content:space-between;align-items:baseline;
  gap:10mm;}
`;

// The receipt works on a different principle from the contract — values
// dropped onto a pre-printed pad rather than a document we lay out — so it
// lives in its own file.
const {receiptHtml} = require("./shari_ashti_receipt");

module.exports = {css, metaHtml, cardHtml, receiptHtml};
