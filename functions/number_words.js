"use strict";

/**
 * Amounts spelled out in Kurdish (Sorani) — the wording that goes beside a
 * figure on a contract or a voucher so the number cannot be altered after the
 * parties have signed it.
 *
 * KURDISH ONLY, deliberately. Arabic numerals inflect for gender, case and the
 * noun they count — ٢٠٠ is "مائتان" or "مئتين" depending on where it stands,
 * and 2 dinars is "ديناران", not "دينارين" — so a naive rendering puts a
 * grammatical error on a document that gets filed with a court. Arabic clauses
 * simply do not carry the `_words` tokens: an unknown token is left visible by
 * the renderer, which is how the person writing the clause finds out.
 */

const ONES = ["", "یەک", "دوو", "سێ", "چوار",
  "پێنج", "شەش", "حەوت", "هەشت", "نۆ"];

const TEENS = ["دە", "یازدە", "دوازدە", "سێزدە", "چواردە",
  "پازدە", "شازدە", "حەڤدە", "هەژدە", "نۆزدە"];

const TENS = ["", "", "بیست", "سی", "چل",
  "پەنجا", "شەست", "حەفتا", "هەشتا", "نەوەد"];

// Written joined, which is the spelling used on documents: سەد، دووسەد، سێسەد…
const HUNDREDS = ["", "سەد", "دووسەد", "سێسەد", "چوارسەد",
  "پێنجسەد", "شەشسەد", "حەوتسەد", "هەشتسەد", "نۆسەد"];

/** Kurdish strings numbers together with a plain "و". */
const JOIN = " و ";

/** Largest amount that spells out; anything above is a data-entry accident. */
const MAX = 1e15;

const SCALES = [
  [1e12, "تریلیۆن"],
  [1e9, "ملیار"],
  [1e6, "ملیۆن"],
  [1e3, "هەزار"],
];

/**
 * The unit names, by currency. Only ever used on an amount that HAS a
 * fraction — see [moneyWords].
 */
const UNIT = {IQD: "دینار", USD: "دۆلار"};
const SUBUNIT = {IQD: "فلس", USD: "سەنت"};

/**
 * 1..999 in words.
 * @param {number} n a whole number in [1, 999]
 * @return {string} the Kurdish wording
 */
function below1000(n) {
  const parts = [];
  const h = Math.floor(n / 100);
  const rest = n % 100;
  if (h) parts.push(HUNDREDS[h]);
  if (rest >= 20) {
    const ones = rest % 10;
    const tens = TENS[Math.floor(rest / 10)];
    parts.push(ones ? tens + JOIN + ONES[ones] : tens);
  } else if (rest >= 10) {
    parts.push(TEENS[rest - 10]);
  } else if (rest) {
    parts.push(ONES[rest]);
  }
  return parts.join(JOIN);
}

/**
 * A whole number in words.
 * @param {number} n a non-negative whole number below [MAX]
 * @return {string} the Kurdish wording, or "" when out of range
 */
function integerWords(n) {
  if (!Number.isFinite(n) || n < 0 || n >= MAX) return "";
  if (n === 0) return "سفر";

  const parts = [];
  let rest = Math.floor(n);
  for (const [value, name] of SCALES) {
    const count = Math.floor(rest / value);
    if (!count) continue;
    rest -= count * value;
    // "هەزار دینار" is how a thousand is said; the یەک would be read as an
    // affectation. The larger scales keep it — "یەک ملیۆن" IS how that is said.
    parts.push(count === 1 && value === 1e3 ?
      name :
      below1000(count) + " " + name);
  }
  if (rest) parts.push(below1000(rest));
  return parts.join(JOIN);
}

/**
 * An amount of money in words, WITHOUT the currency — the clause text places
 * `{currency}` itself, so the wording stays composable.
 *
 * A fraction is the one exception, and it names BOTH units: Kurdish strings
 * numbers with a bare "و", so "نەوەد و نۆ و نەوەد و نۆ سەنت" gives the reader
 * no way to see where the amount ends and the change begins. Naming them —
 * "نەوەد و نۆ دۆلار و نەوەد و نۆ سەنت" — is the only unambiguous reading, and
 * a whole amount (which is nearly all of them) is unaffected.
 *
 * @param {number|string} amount as stored on the document
 * @param {string} [currencyCode] "IQD" | "USD" — only used on a fraction
 * @return {string} the Kurdish wording, or "" when the amount is unusable
 */
function moneyWords(amount, currencyCode) {
  // `|| 0` matches the money() formatters: a missing amount reads as zero
  // rather than as a blank, and null and undefined behave alike.
  const n = Number(amount || 0);
  if (!Number.isFinite(n) || n < 0 || n >= MAX) return "";

  let whole = Math.floor(n);
  // Amounts are stored as plain numbers, so a fraction is possible. Two places
  // is as fine as either currency here divides.
  let frac = Math.round((n - whole) * 100);
  if (frac === 100) {
    whole += 1;
    frac = 0;
  }

  const words = integerWords(whole);
  if (!frac) return words;

  const unit = UNIT[currencyCode];
  const sub = SUBUNIT[currencyCode];
  return words + (unit ? " " + unit : "") +
    JOIN + integerWords(frac) + (sub ? " " + sub : "");
}

module.exports = {integerWords, moneyWords};
