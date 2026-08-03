"use strict";
/**
 * Design template for a single company — copy this file, rename it, and map it
 * to the company's Firestore id in designs/index.js.
 *
 * Two ways to make a company's documents its own. Pick per company; you can
 * mix (e.g. `css` for the receipt, a full `contractHtml`).
 */

// ---------------------------------------------------------------------------
// 1. `css` — restyle the shared layout. Appended after the base stylesheet, so
//    these rules win. Enough when the structure is right and only the look
//    differs. Base classes: .band .logo / .title / .card / .r .rl .rv /
//    .clause / .signs .sg / .foot / .watermark / .attach
// ---------------------------------------------------------------------------
const css = `
.title{font-size:26px;letter-spacing:.5px;}
.card{border-width:2px;border-radius:10px;}
.band .logo{width:70px;height:70px;}
.watermark{opacity:.04;}
`;

// ---------------------------------------------------------------------------
// 2. `contractHtml(vm, o)` — a document of your own, start to finish.
//
//    `vm` is the view model from contract_html.js, with the data work already
//    done, so a bespoke layout only writes markup:
//
//      vm.title           document title (from the company template)
//      vm.clauses         clause texts, {token}s ALREADY substituted
//      vm.names           company name lines (ku/ar/en), blanks dropped
//      vm.logoUri         logo as a data: URI ("" when none)
//      vm.accent          "#RRGGBB" from the template
//      vm.fontSize        clause font size, e.g. "16px"
//      vm.isRent          rent contract vs. sale
//      vm.propertyPairs   [label, value] pairs describing the property
//      vm.footerCells     phone / address strings for the page footer
//      vm.attachments     attachment photos as data: URIs (appendix pages)
//      vm.contract        the raw contract document, for anything else
//      vm.company         raw company document
//      vm.lang            "ku" | "ar" — which edition is being rendered
//      vm.label           every fixed string, already in vm.lang
//      vm.fontRegB64      regular face, base64 — REQUIRED for correct shaping
//      vm.fontBoldB64     bold face, base64
//      vm.esc / vm.money / vm.fmtDate / vm.applyTokens   helpers
//
//    `o` is the untouched input, if you need something vm doesn't expose.
//
//    Three rules for a correct PDF: embed both faces, set `direction:rtl`, and
//    run every dynamic value through `vm.esc`.
//
//    Do NOT hardcode Kurdish text here — take it from vm.label, or the Arabic
//    edition of this contract will come out half-Kurdish. The font bytes are
//    already the right ones for vm.lang (Speda for ku, Amiri for ar), which is
//    why the family below is named generically.
// ---------------------------------------------------------------------------
const contractHtml = (vm) => `<!doctype html>
<html lang="${vm.lang === "ar" ? "ar" : "ckb"}"><head><meta charset="utf-8">
<style>
@font-face{font-family:'DocFont';src:url(data:font/ttf;base64,${vm.fontRegB64}) format('truetype');font-weight:normal;}
@font-face{font-family:'DocFont';src:url(data:font/ttf;base64,${vm.fontBoldB64}) format('truetype');font-weight:bold;}
*{box-sizing:border-box;margin:0;padding:0;}
@page{size:A4;margin:16mm;}
body{font-family:'DocFont';direction:rtl;font-size:${vm.fontSize};line-height:1.7;}
.hd{text-align:center;border-bottom:3px double ${vm.accent};padding-bottom:10px;}
.hd img{height:64px;object-fit:contain;}
.hd h1{color:${vm.accent};font-size:24px;margin-top:8px;}
.info{border:1px solid ${vm.accent};border-radius:8px;padding:8px 12px;margin:12px 0;}
.clause{text-align:justify;margin-bottom:7px;}
.sg{display:inline-block;width:32%;text-align:center;margin-top:36px;}
.sgline{border-top:1px solid #000;margin:20px 12px 4px;}
</style></head><body>
  <div class="hd">
    ${vm.logoUri ? `<img src="${vm.logoUri}">` : ""}
    ${vm.names.map((n) => `<div>${vm.esc(n)}</div>`).join("")}
    <h1>${vm.esc(vm.title)}</h1>
  </div>
  <div class="info">
    <div><b>${vm.esc(vm.label.contractNo)}</b> ${
  vm.esc(vm.contract.contract_number)}</div>
    <div><b>${vm.esc(vm.isRent ? vm.label.party1Rent : vm.label.party1Sale)}</b> ${
  vm.esc(vm.contract.party1_name)}</div>
    <div><b>${vm.esc(vm.isRent ? vm.label.party2Rent : vm.label.party2Sale)}</b> ${
  vm.esc(vm.contract.party2_name)}</div>
    ${vm.propertyPairs
      .map((p) => `<div><b>${vm.esc(p[0])}</b> ${vm.esc(p[1])}</div>`)
      .join("")}
  </div>
  ${vm.clauses
      .map((cl, i) => `<div class="clause">${i + 1}- ${vm.esc(cl)}</div>`)
      .join("")}
  <div>
    <div class="sg"><div class="sgline"></div>${vm.esc(vm.label.sign1)}</div>
    <div class="sg"><div class="sgline"></div>${vm.esc(vm.label.signAgent)}</div>
    <div class="sg"><div class="sgline"></div>${vm.esc(vm.label.sign2)}</div>
  </div>
</body></html>`;

// `receiptHtml(vm, o)` works the same way; its view model comes from
// receipt_html.js and carries titleKu/titleAr/titleEn, personLabelKuAr,
// receivedBy, deliveredTo, dateText, amountText, accent, logoUri, footerCells.

module.exports = {css, contractHtml};
