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

const {hejarFace} = require("./ashti_font");

/**
 * Brand colours, read off the printed contract with a canvas (the scan is a
 * little faded, so these are the most saturated pixels found in each area —
 * the truest reading a photocopy allows). If the company sends their real
 * brand values, these two lines are the only place to change them.
 */
const GOLD = "#F7C10A";
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
 * The lines under the company name on their letterhead: what the firm does,
 * in the three languages, exactly as the printed sheet carries them.
 *
 * SLOGAN is the pair sitting on the rule under the header — the printed sheet
 * they modelled this on reads "your dream, our goal" there. Left blank until
 * the company gives us their own wording: inventing a slogan for a firm is not
 * ours to do.
 *
 * That sheet also carries a QR code beside the header. Crest Home asked for
 * none, so there is none here.
 */
const TAGLINES = [
  "بۆ خزمەتگوزاری عقارات",
  "للخدمات العقارية",
  "For Real Estate Services",
];
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
/* Unikurd Hejar — the face their printed contract is set in. */
${hejarFace()}
html:not([lang="en"]) body{font-family:'Hejar','DocFont' !important;}
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
/* Logo left, the company's names stacked in the middle, and a rule under the
   lot. The shared band writes the names first and the logo second, which in
   Kurdish and Arabic already puts the logo on the left; the English edition
   has to be told. */
.band{display:flex;align-items:center;justify-content:space-between;
  padding:0 0 1mm;}
.band .logo{width:auto;height:20mm;object-fit:contain;margin:0;}
html[dir="ltr"] .band .logo{order:-1;}
.band .names{flex:1;text-align:center;}
/* One masthead, as on their sheet, not the company's name in three languages
   stacked: the edition's own name is the big gold one and the others are put
   away. The shared band lists Kurdish, Arabic, English — except the Arabic
   edition, which drops the Kurdish and so leads with the right one already. */
.band .names div{display:none;}
.band .names div:first-child{display:block;font-size:26pt;color:${GOLD};
  font-weight:bold;line-height:1.2;}
html[lang="en"] .band .names div:first-child{display:none;}
html[lang="en"] .band .names div:last-child{display:block;font-size:26pt;
  color:${GOLD};font-weight:bold;line-height:1.2;}
.band .names::after{content:"${lines(TAGLINES)}";white-space:pre-line;
  display:block;font-size:10pt;font-weight:bold;color:${SLATE};line-height:1.45;}

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
/* Their heading is a gold band across the page, squared off at the start and
   rounded at the end. */
.chead{background:${GOLD};color:#fff;font-size:12pt !important;
  font-weight:bold;text-align:center;padding:1.6mm 6mm;
  border-radius:3mm 0 0 3mm;margin:0 0 4mm !important;}
html[dir="ltr"] .chead{border-radius:0 3mm 3mm 0;}

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
.foot{border:0;padding:0 14mm 12mm;display:flex;justify-content:space-between;
  align-items:flex-end;font-size:10pt;font-weight:bold;color:${SLATE};
  gap:8mm;white-space:pre-line;}
.foot span{display:inline-block;}
/* A phone and a pin, drawn rather than fetched: no network in the renderer. */
.foot span:first-child::before, .foot span:last-child::before{
  content:"";display:inline-block;width:4.2mm;height:4.2mm;
  margin-inline-end:2mm;vertical-align:-0.9mm;background-size:contain;
  background-repeat:no-repeat;}
.foot span:first-child::before{background-image:url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'>\
<circle cx='12' cy='12' r='12' fill='%23${GOLD.slice(1)}'/>\
<path fill='%23fff' d='M17.4 15.1l-2-.9a.9.9 0 00-1 .2l-.8.9a8 8 0 01-3.9-3.9l.9-.8a.9.9 0 00.2-1l-.9-2a.9.9 0 00-1-.5l-1.7.4a1 1 0 00-.8 1c.2 5 4.2 9 9.2 9.2a1 1 0 001-.8l.4-1.7a.9.9 0 00-.6-1.1z'/></svg>");}
.foot span:last-child::before{background-image:url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'>\
<circle cx='12' cy='12' r='12' fill='%23${GOLD.slice(1)}'/>\
<path fill='%23fff' d='M12 5.5a4.4 4.4 0 00-4.4 4.4c0 3.3 4.4 8.6 4.4 8.6s4.4-5.3 4.4-8.6A4.4 4.4 0 0012 5.5zm0 6a1.6 1.6 0 110-3.2 1.6 1.6 0 010 3.2z'/></svg>");}
/* The bar: gold across, with two slate chevrons at the outer end. */
.foot::after{content:"";position:absolute;left:0;right:0;bottom:0;height:7mm;
  background:
    linear-gradient(115deg, transparent 0 62%, ${SLATE} 62% 70%,
      transparent 70% 73%, ${SLATE} 73% 81%, transparent 81%),
    linear-gradient(${GOLD}, ${GOLD});
  background-size:100% 100%;}

/* What the footer takes out of every page: the phones and address, the bar,
   and air above them. The rehearsal subtracts this, so the clauses stop clear
   of the footer instead of printing through it. */
.footspace{height:24mm !important;}

/* Their sheets carry no watermark. */
.watermark{display:none !important;}
`;

/**
 * The voucher takes none of the CSS above — those are page margins and
 * letterhead rules for a document laid out nothing like it — but it does get
 * the foot of their letterhead, which the company asked for: the phones and
 * the address on white with gold markers, over a gold bar that a pair of
 * chevrons cuts across at the end.
 *
 * The shared footer is a solid bar of the accent colour with the three
 * details spaced along it, so this re-lays those same three: phones stacked
 * on one side, address on the other. `background` is set on the element
 * itself by the renderer, hence the !important.
 */
const receiptCss = `
/* direction:ltr so the columns run the way their sheet does — phones at the
   left, address across the middle — whatever language the voucher is in. The
   address is put back to rtl for its own text; the phone numbers are figures
   and read left to right either way. */
.footer{background:transparent !important;color:${SLATE};height:auto;
  border-radius:0;margin-top:10px;padding:0 10px 16px;position:relative;
  direction:ltr;display:grid;grid-template-columns:auto 1fr;
  align-items:center;font-weight:bold;line-height:1.6;}
/* The dividers belong to the bar this replaces. */
.footer .sep{display:none;}
/* Children run phone, divider, phone, divider, address. */
.footer > span:nth-child(1){grid-area:1 / 1;}
.footer > span:nth-child(3){grid-area:2 / 1;}
.footer > span:nth-child(5){grid-area:1 / 2 / span 2;text-align:center;
  direction:rtl;}
/* A phone and a pin, drawn rather than fetched: no network in the renderer. */
/* The pin goes on ::after for the address: that span reads right to left, so
   its ::after is the physical left — which is the side their sheet has the
   marker on, the same side as the phone icon. */
.footer > span:nth-child(1)::before, .footer > span:nth-child(5)::after{
  content:"";display:inline-block;width:9px;height:9px;
  vertical-align:-1px;background-size:contain;background-repeat:no-repeat;}
.footer > span:nth-child(1)::before{margin-inline-end:4px;}
.footer > span:nth-child(5)::after{margin-inline-start:4px;}
.footer > span:nth-child(1)::before{background-image:url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'>\
<circle cx='12' cy='12' r='12' fill='%23${GOLD.slice(1)}'/>\
<path fill='%23fff' d='M17.4 15.1l-2-.9a.9.9 0 00-1 .2l-.8.9a8 8 0 01-3.9-3.9l.9-.8a.9.9 0 00.2-1l-.9-2a.9.9 0 00-1-.5l-1.7.4a1 1 0 00-.8 1c.2 5 4.2 9 9.2 9.2a1 1 0 001-.8l.4-1.7a.9.9 0 00-.6-1.1z'/></svg>");}
.footer > span:nth-child(5)::after{background-image:url("data:image/svg+xml;utf8,\
<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'>\
<circle cx='12' cy='12' r='12' fill='%23${GOLD.slice(1)}'/>\
<path fill='%23fff' d='M12 5.5a4.4 4.4 0 00-4.4 4.4c0 3.3 4.4 8.6 4.4 8.6s4.4-5.3 4.4-8.6A4.4 4.4 0 0012 5.5zm0 6a1.6 1.6 0 110-3.2 1.6 1.6 0 010 3.2z'/></svg>");}
/* The bar: gold across, cut by two chevrons in the company's brown near the
   end, as on the sheet they sent. */
.footer::after{content:"";position:absolute;left:0;right:0;bottom:0;height:9px;
  background:
    linear-gradient(115deg, transparent 0 74%, ${BROWN} 74% 80%,
      transparent 80% 83%, ${BROWN} 83% 89%, transparent 89%),
    linear-gradient(${GOLD}, ${GOLD});}
`;

module.exports = {css, receiptCss, receiptAccent: BROWN, metaHtml, cardHtml};
