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

// The count and سەد stay separate words — «پێنج سەد», not «پێنجسەد». Both
// spellings are current, and this is the one the office writes by hand.
const HUNDREDS = ["", "سەد", "دوو سەد", "سێ سەد", "چوار سەد",
  "پێنج سەد", "شەش سەد", "حەوت سەد", "هەشت سەد", "نۆ سەد"];

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

// ---------------------------------------------------------------------------
// English
// ---------------------------------------------------------------------------

const EN_ONES = ["", "one", "two", "three", "four", "five", "six", "seven",
  "eight", "nine", "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen",
  "sixteen", "seventeen", "eighteen", "nineteen"];

const EN_TENS = ["", "", "twenty", "thirty", "forty", "fifty", "sixty",
  "seventy", "eighty", "ninety"];

const EN_SCALES = [
  [1e12, "trillion"],
  [1e9, "billion"],
  [1e6, "million"],
  [1e3, "thousand"],
];

const EN_UNIT = {IQD: "dinars", USD: "dollars"};
const EN_SUBUNIT = {IQD: "fils", USD: "cents"};

/**
 * 1..999 in English.
 * @param {number} n a whole number in [1, 999]
 * @return {string} the wording
 */
function enBelow1000(n) {
  const parts = [];
  const h = Math.floor(n / 100);
  const rest = n % 100;
  if (h) parts.push(EN_ONES[h] + " hundred");
  if (rest) {
    // "one hundred AND five" — the British form, which is what a contract
    // written in Erbil is read in.
    if (h) parts.push("and");
    if (rest < 20) {
      parts.push(EN_ONES[rest]);
    } else {
      const ones = rest % 10;
      const tens = EN_TENS[Math.floor(rest / 10)];
      parts.push(ones ? tens + "-" + EN_ONES[ones] : tens);
    }
  }
  return parts.join(" ");
}

/**
 * A whole number in English.
 * @param {number} n a non-negative whole number below [MAX]
 * @return {string} the wording, or "" when out of range
 */
function enIntegerWords(n) {
  if (!Number.isFinite(n) || n < 0 || n >= MAX) return "";
  if (n === 0) return "zero";

  const parts = [];
  let rest = Math.floor(n);
  for (const [value, name] of EN_SCALES) {
    const count = Math.floor(rest / value);
    if (!count) continue;
    rest -= count * value;
    parts.push(enBelow1000(count) + " " + name);
  }
  if (rest) parts.push(enBelow1000(rest));
  return parts.join(" ");
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
 * @param {string} [lang] "ku" (default) or "en"
 * @return {string} the wording, or "" when the amount is unusable
 */
function moneyWords(amount, currencyCode, lang) {
  // `|| 0` matches the money() formatters: a missing amount reads as zero
  // rather than as a blank, and null and undefined behave alike.
  const n = Number(amount || 0);
  if (!Number.isFinite(n) || n < 0 || n >= MAX) return "";

  const en = lang === "en";
  const spell = en ? enIntegerWords : integerWords;
  const join = en ? " and " : JOIN;
  const unit = (en ? EN_UNIT : UNIT)[currencyCode];
  const sub = (en ? EN_SUBUNIT : SUBUNIT)[currencyCode];

  let whole = Math.floor(n);
  // Amounts are stored as plain numbers, so a fraction is possible. Two places
  // is as fine as either currency here divides.
  let frac = Math.round((n - whole) * 100);
  if (frac === 100) {
    whole += 1;
    frac = 0;
  }

  const words = spell(whole);
  if (!frac) return words;

  return words + (unit ? " " + unit : "") +
    join + spell(frac) + (sub ? " " + sub : "");
}

module.exports = {integerWords, enIntegerWords, moneyWords};
