"use strict";
/**
 * Which stored colours mean "nobody chose this".
 *
 * The app writes the whole template back when it is saved, defaults and all,
 * so a company that never opened the colour picker still ends up with a
 * colour in its record. Read literally, that beats the colour a company's own
 * design asks for: Crest Home's vouchers came out in the app's blue rather
 * than their brown, twice, because their template had been saved at some
 * point and the saved value won.
 *
 * So a value that is one of the colours the app has ever shipped as its
 * factory setting counts as unset, and the design's own colour stands.
 * Anything else in that field was picked by a person, and is theirs.
 *
 * The cost of being wrong here is a company that deliberately picks exactly
 * the house navy and is given its design's colour instead — which is the
 * shade it was already going to print for everyone on the house design.
 */
const FACTORY = new Set([
  "0F2C59", // the app's first default, and contract_defaults' primary_color
  "1E4D8B", // the voucher blue that went with it
  "03286E", // the brand sheet's logo navy, shipped for a while
  "001E52", // the logo's own navy, the default since the house design
]);

/**
 * @param {string} v a colour as stored or as CSS ("1E4D8B" or "#1E4D8B")
 * @return {boolean} true when it is a factory colour or nothing at all
 */
const isFactory = (v) => {
  const bare = String(v == null ? "" : v).replace(/^#/, "").toUpperCase();
  return !bare || FACTORY.has(bare);
};

module.exports = {FACTORY, isFactory};
