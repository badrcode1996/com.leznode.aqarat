"use strict";
/**
 * Per-company PDF designs.
 *
 * The app is B2B with a small, hand-onboarded customer list, so a bespoke
 * design per company is checked into the repo and shipped with a deploy —
 * there is no runtime design editor beyond the colour/font knobs in the
 * `templates` document.
 *
 * A design module may export any of:
 *
 *   css          — extra CSS appended AFTER the base stylesheet, so any rule
 *                  here overrides the default look. This is the cheap path:
 *                  most companies need only a few rules.
 *   contractHtml — (o) => string. Full takeover of the contract document.
 *                  Only for layouts the base template can't be pushed into.
 *   receiptHtml  — (o) => string. Same, for the receipt (وەصڵ).
 *
 * Anything omitted falls back to the shared default in contract_html.js /
 * receipt_html.js — so a bug fixed in the base layout is fixed for every
 * company that didn't take the layout over.
 *
 * To onboard a company: add `designs/<slug>.js`, then map its company id here.
 * The id is the `companies` document id, which is already the slug of the
 * English name (Company.slugify: "Al Azud Real Estate" -> "al_azud_real_estate"),
 * so these keys stay readable — no opaque ids to look up.
 */

const REGISTRY = {
  // "al_azud_real_estate": require("./al_azud_real_estate"),
};

const EMPTY = {};

/**
 * The design for a company, or an empty design (= the shared default look).
 * @param {string} companyId Firestore `companies` document id.
 * @return {{css?: string, contractHtml?: Function, receiptHtml?: Function}}
 */
function resolveDesign(companyId) {
  // Own-property check: a company id like "constructor" or "toString" would
  // otherwise resolve to something off Object.prototype.
  if (!companyId || !Object.prototype.hasOwnProperty.call(REGISTRY, companyId)) {
    return EMPTY;
  }
  return REGISTRY[companyId] || EMPTY;
}

module.exports = {resolveDesign, REGISTRY};
