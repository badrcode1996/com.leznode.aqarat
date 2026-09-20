"use strict";
/**
 * Unikurd Hejar, base64, read once per container.
 *
 * Shared because Ashti's contract and their receipt both set in it, and the
 * two are built by different files. Reading it in each would parse 62KB twice
 * and, worse, let the two drift onto different faces.
 *
 * Only the regular face is declared, and deliberately so. There is no bold cut
 * of this font, so bold has to be synthesised — but declaring a second
 * @font-face at font-weight:bold pointing at the SAME file tells Chrome a real
 * bold exists, and it then stops synthesising one. Everything asked to print
 * bold — the title, the receipt values — came out at regular weight.
 */

const fs = require("fs");
const path = require("path");

const HEJAR = fs
    .readFileSync(path.join(__dirname, "..", "fonts", "UnikurdHejar.ttf"))
    .toString("base64");

/**
 * The @font-face, ready to drop into a stylesheet.
 *
 * @param {string} [family] the family name to declare it under
 * @return {string} CSS
 */
const hejarFace = (family) => {
  const f = family || "Hejar";
  const src = `url(data:font/ttf;base64,${HEJAR}) format('truetype')`;
  return `@font-face{font-family:'${f}';src:${src};font-weight:normal;font-style:normal;}`;
};

module.exports = {HEJAR, hejarFace};
