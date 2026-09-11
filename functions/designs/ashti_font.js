"use strict";
/**
 * Unikurd Hejar, base64, read once per container.
 *
 * Shared because Ashti's contract and their receipt both set in it, and the
 * two are built by different files. Reading it in each would parse 62KB twice
 * and, worse, let the two drift onto different faces.
 *
 * One file for both weights: there is no separate bold cut, so the renderer
 * synthesises it — which is what the Windows program it replaces did too.
 */

const fs = require("fs");
const path = require("path");

const HEJAR = fs
    .readFileSync(path.join(__dirname, "..", "fonts", "UnikurdHejar.ttf"))
    .toString("base64");

/**
 * The @font-face pair, ready to drop into a stylesheet.
 *
 * @param {string} [family] the family name to declare it under
 * @return {string} CSS
 */
const hejarFace = (family) => {
  const f = family || "Hejar";
  const src = `url(data:font/ttf;base64,${HEJAR}) format('truetype')`;
  return `@font-face{font-family:'${f}';src:${src};font-weight:normal;font-style:normal;}\n` +
    `@font-face{font-family:'${f}';src:${src};font-weight:bold;font-style:normal;}`;
};

module.exports = {HEJAR, hejarFace};
