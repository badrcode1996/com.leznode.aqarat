"use strict";
/**
 * Phone numbers, as a phone number is written.
 *
 * Two things go wrong when a number is printed like the rest of the page.
 * Its digits are rewritten as ٠-٩ along with every other figure on the
 * document, and a run of Arabic-Indic digits is laid out right to left, so
 * "0750 402 4288   0770 300 4000" comes off the press with its groups in the
 * other order. Nobody can dial that.
 *
 * So a number prints in Latin digits, grouped with dashes — 0750-123-4567 —
 * which reads the same way in all three editions and cannot be reordered.
 */

/** Arabic-Indic (٠-٩) and Eastern Arabic-Indic (۰-۹) to 0-9. */
const toLatin = (s) => String(s == null ? "" : s)
    .replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 0x0660))
    .replace(/[۰-۹]/g, (d) => String(d.charCodeAt(0) - 0x06F0));

/**
 * One number, grouped. An Iraqi mobile is eleven digits (07501234567), which
 * groups 4-3-4; a landline is ten, which groups 3-3-4. Anything else is left
 * as it was typed, only with its digits in Latin — guessing at the grouping
 * of a number we do not recognise would be worse than printing it plainly.
 *
 * @param {string} v a phone number as stored
 * @return {string} the number as it should print
 */
const fmtPhone = (v) => {
  const text = toLatin(v).trim();
  if (!text) return "";
  const d = text.replace(/\D/g, "");
  if (d.length === 11 && d[0] === "0") {
    return `${d.slice(0, 4)}-${d.slice(4, 7)}-${d.slice(7)}`;
  }
  if (d.length === 10) {
    return `${d.slice(0, 3)}-${d.slice(3, 6)}-${d.slice(6)}`;
  }
  return text;
};

/**
 * The company's numbers on one line.
 *
 * @param {Array<string>} list the numbers, blanks and all
 * @param {string} [sep] what goes between them
 * @return {string} the line, empty when there are no numbers
 */
const joinPhones = (list, sep) => (list || [])
    .map(fmtPhone).filter(Boolean).join(sep === undefined ? "   /   " : sep);

module.exports = {fmtPhone, joinPhones, toLatin};
