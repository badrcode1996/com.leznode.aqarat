"use strict";
/**
 * Crest Home.
 *
 * Built to a printed contract the company handed us as the look they want: a
 * gold-and-slate letterhead drawn by the document itself (their sheets are
 * plain paper, unlike Shari Ashti's), a three-column line carrying the date,
 * the title and the contract number, the parties and the property in two
 * columns, a gold band introducing the clauses, and a footer with the phones
 * and the address over a chevron bar.
 *
 * Deliberately NOT a contractHtml takeover. Everything below is CSS over the
 * shared document plus the two block hooks, so this company keeps every fix
 * made to the base layout — including the pass that keeps the signatures on
 * the foot of the last page.
 */

/**
 * The slate the body text and the header rule are set in, read off the
 * printed contract this design started from.
 *
 * The gold that went with it is gone: band by band the company asked for
 * their own brown instead, until nothing was left in it.
 */
const SLATE = "#2E3D45";

/**
 * The brown of their logo, which their vouchers print in instead of the house
 * blue. Taken as the commonest ink colour in the logo they sent (the dominant
 * bins were #582808 and #683818; this sits between them, dark enough to carry
 * white text on the banner).
 *
 * A default, not an override — a colour picked in the app still wins.
 */
const BROWN = "#6B3A18";

/**
 * SLOGAN is the pair sitting on the rule under the header — the printed sheet
 * they modelled this on reads "your dream, our goal" there. Left blank until
 * the company gives us their own wording: inventing a slogan for a firm is not
 * ours to do.
 *
 * (That sheet also carried three lines describing the trade under the company
 * name. The company asked for the voucher's letterhead here instead, which
 * has the name, the logo and the English wordmark and nothing else.)
 *
 * That sheet also carries a QR code beside the header. Crest Home asked for
 * none, so there is none here.
 */
const {WORDMARK, NAME_KU} = require("./crest_home_brand");

/**
 * The letterhead, laid out like the one on their voucher: the Kurdish name on
 * one side, the logo in the middle, the English wordmark on the other. Their
 * two documents are handed over together, so they open the same way.
 *
 * The logo arrives as the shared <img>; .ch-logo crops the empty space out of
 * the file — see the stylesheet.
 *
 * @param {object} vm the contract view model
 * @param {object} parts {logo} the logo markup, already a data: URI
 * @return {string} markup
 */
const bandHtml = (vm, parts) => `
  <div class="ch-name">
    ${NAME_KU.map((l, i) =>
    `<div class="${i ? "ch-n2" : "ch-n1"}">${vm.esc(l)}</div>`).join("")}
  </div>
  <div class="ch-logo">${parts.logo}</div>
  <div class="ch-mark">
    ${WORDMARK.map((l, i) =>
    `<div class="${i ? "ch-m2" : "ch-m1"}">${vm.esc(l)}</div>`).join("")}
  </div>`;

const SLOGAN = {ku: "", ar: ""};

/** CSS string list, for a ::after that prints one line per entry. */
const lines = (arr) => arr.filter(Boolean)
    .map((t) => JSON.stringify(t).slice(1, -1))
    .join("\\A ");

/**
 * The line their contracts open with: the date on one side, the title in the
 * middle, the contract number on the other.
 *
 * The shared title above it is hidden by the CSS below, so the document still
 * has exactly one — this one, where their printed form puts it.
 *
 * @param {object} vm the contract view model
 * @return {string} markup
 */
const metaHtml = (vm) => `
<div class="ch-meta">
  <span class="ch-date"><b>${vm.esc(vm.label.date)}</b> ${vm.esc(vm.dateText)}</span>
  <span class="ch-title">(${vm.esc(vm.title)})</span>
  <span class="ch-no"><b>${vm.esc(vm.label.contractNo)}</b> ${vm.esc(vm.contract.contract_number || "")}</span>
</div>`;

/**
 * Parties and property, two to a line as on their form: first party beside
 * second party, then the property facts paired off.
 *
 * @param {object} vm the contract view model
 * @return {string} markup
 */
const cardHtml = (vm) => {
  const e = vm.esc;
  const c = vm.contract;
  const T = vm.label;

  const cell = (label, value) =>
    `<div class="ch-cell"><span class="ch-l">${e(label)}</span> ` +
    `<span class="ch-v">${e(value || "")}</span></div>`;

  const parties = vm.isRent ?
    [[T.party1Rent, c.party1_name], [T.party2Rent, c.party2_name]] :
    [[T.party1Sale, c.party1_name], [T.party2Sale, c.party2_name]];

  // propertyPairs runs type, project, number, area. Their form pairs the
  // place with the kind, then the number with the area.
  const [type, project, number, area] = vm.propertyPairs;

  return `<div class="ch-card">` +
    [parties[0], parties[1], project, type, number, area]
        .map(([l, v]) => cell(l, v)).join("") +
    `</div>`;
};

const css = `
/* Speda, the house face — what the company asked for. 'DocFont' is the
   shared family the renderer embeds per language (Speda for Kurdish and
   English, Amiri for Arabic), so naming it is all this needs. */
body{font-size:12pt !important;color:${SLATE};}

/* Room for the letterhead the document draws itself: the header block repeats
   through the table's thead, the footer is fixed to the foot of every page.
   No bottom margin, deliberately — a fixed element sits at the bottom of the
   page's CONTENT box, so any margin there would float the chevron bar above
   the edge of the sheet instead of running it off the bottom as their printed
   contract does. The space the footer needs is reserved by .footspace below,
   which is what the page rehearsal measures. */
@page{margin:8mm 14mm 0;}
:root{--page-h:289mm;--text-w:182mm;
  /* Their contract ends with the signatures under the last clauses rather
     than on a page of their own. */
  --min-tail:3;}

/* --- Letterhead ------------------------------------------------------- */
/* Three columns, as on their voucher: the Kurdish name, the logo, the English
   wordmark. Written by bandHtml above rather than styled out of the shared
   band, which carries the company's names and nothing else. */
.band{display:flex;align-items:center;justify-content:space-between;
  gap:6mm;padding:0 0 1mm;}
.ch-name{flex:1;text-align:right;}
.ch-mark{flex:1;text-align:left;}
html[dir="ltr"] .ch-name{text-align:left;}
html[dir="ltr"] .ch-mark{text-align:right;}
.ch-n1{font-size:12pt;font-weight:bold;color:${BROWN};line-height:1.3;}
.ch-n2{font-size:20pt;font-weight:bold;color:${BROWN};line-height:1.25;}
.ch-m1{font-size:17pt;font-weight:bold;color:${BROWN};line-height:1.25;
  letter-spacing:0.5px;text-transform:uppercase;}
.ch-m2{font-size:12.5pt;font-weight:bold;color:${BROWN};line-height:1.25;
  letter-spacing:0.5px;text-transform:uppercase;}

/* The logo file is mostly empty space — 28.9% of its height above the mark
   and 33.1% below, measured on the file the company sent — which is why it
   read as small here however large the box was. The box is clipped to the
   artwork instead, so the mark fills it.

   Same arithmetic as the voucher (see crest_home_receipt.js), for 26mm of
   artwork: 26 / 0.379 = 68.6mm tall, pulled up by 0.289 x 68.6 = 19.8mm.
   REDO BOTH IF THE LOGO FILE CHANGES. */
.ch-logo{flex:0 0 auto;height:26mm;overflow:hidden;line-height:0;}
.band .logo{display:block;width:auto;height:68.6mm;margin:-19.8mm 0 0;
  object-fit:contain;}

/* The rule, with the company's slogan sitting on it either side. */
.bandline{border-bottom:1.2px solid ${SLATE};margin:0 0 4mm;
  display:flex;justify-content:space-between;font-size:9pt;font-weight:bold;
  color:${SLATE};}
.bandline::before{content:"${lines([SLOGAN.ku])}";}
.bandline::after{content:"${lines([SLOGAN.ar])}";}

/* --- Date · title · number -------------------------------------------- */
/* One row, the title in the middle. The shared title block is hidden: this
   line carries it, as their form does. */
.title{display:none !important;}
.ch-meta{display:flex;justify-content:space-between;align-items:baseline;
  margin:0 0 5mm;font-size:12pt;}
.ch-title{font-size:14pt;font-weight:bold;color:${SLATE};}

/* --- Parties and property --------------------------------------------- */
/* Two columns, reading right to left in Kurdish and Arabic and left to right
   in English, which grid handles on its own. */
.ch-card{display:grid;grid-template-columns:1fr 1fr;gap:3mm 8mm;
  margin:0 0 6mm;}
.ch-cell{white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}
.ch-l{font-weight:bold;}

/* --- The clauses ------------------------------------------------------- */
/* A band across the page in the company's brown — the colour their name is
   set in — and a plain rectangle, like the one on their voucher. It was gold
   and tapered at one end, from the printed contract this design started from;
   the company asked for their own colour and shape. */
.chead{background:${BROWN};color:#fff;font-size:12pt !important;
  font-weight:bold;text-align:center;padding:1.6mm 6mm;
  border-radius:1mm;margin:0 0 4mm !important;}

/* The number hangs in the margin beside the clause, which is what gives their
   page its column of numerals down the edge. */
.clause{line-height:1.75;margin-bottom:3.5mm !important;
  padding-inline-start:9mm;text-indent:-9mm;}

.notes{margin-top:6mm;}

/* --- Signatures -------------------------------------------------------- */
/* Three names across the foot of the last page, over their own rules. */
.signs{gap:8mm;margin-top:16mm;}
.sgl{font-size:11pt;font-weight:bold;color:${SLATE};}
.sgline{border-top:1px solid ${SLATE};width:55mm;margin:14mm auto 3mm;}
.sgn{font-size:11pt !important;color:${SLATE};}

/* --- Footer ------------------------------------------------------------ */
/* Phones on one side, address on the other, and the chevron bar under them.
   .foot is fixed, so this prints on every page as it does on theirs. */
/* One brown bar across the foot, the same as the voucher's, with the phones
   and the address inside it.

   Width is pinned to the text column — 210mm less the 14mm margins either
   side — and centred, rather than offset from the page edges: a fixed box's
   edges and the flow's edges are not the same thing in print, and the company
   wants this bar exactly as long as the clause band above it. Its padding and
   size match that band too, so the two are the same depth.

   .foot is fixed, so it prints at the foot of every page. */
.foot{position:fixed;bottom:9mm;left:50%;transform:translateX(-50%);
  width:182mm;border:0;background:${BROWN};color:#fff;border-radius:1mm;
  padding:1.6mm 6mm;display:flex;justify-content:space-between;
  align-items:center;gap:6mm;font-size:12pt;font-weight:bold;
  white-space:pre-line;}
/* The phone numbers read left to right whatever the page does. */
.foot span:first-child{direction:ltr;letter-spacing:0.5px;}

/* What the footer takes out of every page: the phones and address, the bar,
   and air above them. The rehearsal subtracts this, so the clauses stop clear
   of the footer instead of printing through it. */
.footspace{height:24mm !important;}

/* Their sheets carry no watermark. */
.watermark{display:none !important;}
`;

// The voucher is a different document from the contract — their own form,
// one language, its own header and footer — so it is laid out in full rather
// than styled over the shared one, and lives in its own file.
const {receiptHtml} = require("./crest_home_receipt");

module.exports =
  {css, receiptHtml, receiptAccent: BROWN, bandHtml, metaHtml, cardHtml};
