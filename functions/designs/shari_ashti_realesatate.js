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

const fs = require("fs");
const path = require("path");

/**
 * Unikurd Hejar, base64, read once per container.
 *
 * One file, used for both weights — there is no separate bold cut, so the
 * renderer synthesises it, which is what the old Windows program did too.
 */
const HEJAR = fs
    .readFileSync(path.join(__dirname, "..", "fonts", "UnikurdHejar.ttf"))
    .toString("base64");

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

const css = `
/* Unikurd Hejar, what this company's paperwork has always been set in. Named
   as its own family rather than redefining DocFont, so which face is in use
   is unambiguous rather than depending on declaration order. */
@font-face{font-family:'Hejar';src:url(data:font/ttf;base64,${HEJAR}) format('truetype');font-weight:normal;font-style:normal;}
@font-face{font-family:'Hejar';src:url(data:font/ttf;base64,${HEJAR}) format('truetype');font-weight:bold;font-style:normal;}
body{font-family:'Hejar','DocFont' !important;}

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
   title, which is where they sat on the printed forms. */
.ashti-meta{margin:6px 0 10px;line-height:1.9;}
.ashti-meta div{text-align:right;}
.ashti-meta b{color:inherit;}
`;

// The receipt works on a different principle from the contract — values
// dropped onto a pre-printed pad rather than a document we lay out — so it
// lives in its own file.
const {receiptHtml} = require("./shari_ashti_receipt");

module.exports = {css, metaHtml, receiptHtml};
