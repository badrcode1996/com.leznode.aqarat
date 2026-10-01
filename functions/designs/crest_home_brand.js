"use strict";
/**
 * Crest Home — the bits of their identity both documents print.
 *
 * Shared so the contract and the voucher cannot drift apart: the wordmark is
 * set by hand rather than taken from the company record, because the record
 * holds a legal name ("Crest Home Company") and this is how the firm writes
 * itself on paper, over two lines.
 */

const WORDMARK = ["Crest Home", "Real Estate"];

/**
 * The Kurdish masthead, also over two lines: the trade above, the name below.
 * Set by hand for the same reason as the wordmark — the company record holds
 * "کۆمپانیای کریست هۆم" as one line, and their voucher breaks it.
 */
const NAME_KU = ["کۆمپانیای عقارات", "کرێست هۆم"];

/**
 * The brown of their logo, which both their documents print in instead of the
 * house navy. Taken as the commonest ink colour in the logo they sent (the
 * dominant bins were #582808 and #683818; this sits between them, dark enough
 * to carry white text on a band).
 *
 * It lives here, beside the wordmark, because the contract and the voucher
 * both need it and neither file can require the other.
 */
const BROWN = "#6B3A18";

module.exports = {WORDMARK, NAME_KU, BROWN};
