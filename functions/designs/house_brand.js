"use strict";
/**
 * The house colours, in their own file so the contract design and the voucher
 * design can both read them without requiring each other.
 *
 * The two inks of the Grebast logo, sampled from assets/images/app_logo.png:
 * these are the two commonest colours in the file after the white ground
 * (#001E52 x5092 with #011F53 beside it, #F79226 x1375 with #F79125 beside
 * it). The brand sheet rounds them to #0F2C59 and #F8B115; the file is what
 * the mark actually prints in, and the mark sits at the top of every page
 * these designs draw.
 */
const NAVY = "#001E52";
const GOLD = "#F79226";

/**
 * The colours the app has shipped as "the default" over time. A company that
 * never touched the colour picker has one of these stored in its template, so
 * they mean "unset" rather than "chosen": they map to the navy above, and the
 * house look reaches those companies without anyone reopening the editor.
 *
 * Anything else in that field was picked by a person and is left alone — the
 * picker still means something.
 */
const LEGACY = new Set(["0F2C59", "1E4D8B", "03286E"]);

/**
 * The document's main ink: the company's own colour when it chose one, the
 * logo navy otherwise.
 *
 * @param {string} accent vm.accent, e.g. "#0F2C59"
 * @return {string} a CSS colour
 */
const ink = (accent) => {
  const bare = String(accent || "").replace(/^#/, "").toUpperCase();
  return (!bare || LEGACY.has(bare)) ? NAVY : "#" + bare;
};

module.exports = {NAVY, GOLD, ink};
