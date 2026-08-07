/**
 * Daily due-date scan.
 *
 * Walks every rent contract, raises a `notifications` document for each rent
 * installment that has just fallen due (or is about to) and for each lease
 * term that ends within the month, then pushes ONE summary FCM message per
 * user who has something new.
 *
 * Design notes:
 *
 * - Notification ids are deterministic (`<contractId>__<type>__m<n>`), so a
 *   rerun — a retry, a redeploy, a manual invocation — can never duplicate an
 *   alert. Existence is checked before writing rather than relying on
 *   `create()` throwing, because one ALREADY_EXISTS would abort the whole
 *   batch.
 *
 * - One push per user, not per notification. A company onboarding a year of
 *   back-dated contracts would otherwise get its staff a hundred pushes in one
 *   morning and be uninstalled by lunchtime.
 *
 * - Everything is per-company best-effort: a single tenant with malformed data
 *   must not stop the other tenants' alerts.
 */

const {FieldValue} = require("firebase-admin/firestore");

// Asia/Baghdad is UTC+3 all year (Iraq dropped DST in 2008), so a fixed offset
// is enough to find local day boundaries — the container clock is UTC.
const TZ_OFFSET_MS = 3 * 60 * 60 * 1000;

/** Raise a "due soon" alert this many days before an installment is due. */
const DUE_SOON_DAYS = 3;

/** Raise an "expiring" alert this many days before the lease term ends. */
const EXPIRY_DAYS = 30;

/** Notifications older than this are pruned on each run. */
const RETENTION_DAYS = 90;

/** Firestore caps a batch at 500 writes and getAll at a few hundred reads. */
const CHUNK = 300;

/** FCM caps a multicast send at 500 tokens. */
const TOKEN_CHUNK = 500;

const CURRENCY_LABEL = {IQD: "د.ع", USD: "$"};

const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * Midnight in Baghdad for the day that [ms] falls in, as a UTC timestamp.
 *
 * @param {number} ms Epoch milliseconds.
 * @return {number} Epoch milliseconds of local midnight.
 */
function startOfLocalDay(ms) {
  const shifted = ms + TZ_OFFSET_MS;
  return Math.floor(shifted / DAY_MS) * DAY_MS - TZ_OFFSET_MS;
}

/**
 * Formats a timestamp as yyyy/MM/dd in Baghdad local time — matching the
 * DateFormat the app uses everywhere else.
 *
 * @param {number} ms Epoch milliseconds.
 * @return {string} The formatted date.
 */
function formatDate(ms) {
  const d = new Date(ms + TZ_OFFSET_MS);
  const mm = String(d.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(d.getUTCDate()).padStart(2, "0");
  return `${d.getUTCFullYear()}/${mm}/${dd}`;
}

/**
 * Milliseconds of a Firestore Timestamp, or 0 when the field is missing.
 *
 * @param {object} ts A Firestore Timestamp, or undefined.
 * @return {number} Epoch milliseconds.
 */
function toMs(ts) {
  return ts && typeof ts.toMillis === "function" ? ts.toMillis() : 0;
}

/**
 * Adds whole months to a timestamp, clamping to the end of a shorter month
 * (31 Jan + 1 month → 28/29 Feb, never 2/3 March).
 *
 * @param {number} ms Epoch milliseconds.
 * @param {number} months Months to add.
 * @return {number} Epoch milliseconds.
 */
function addMonths(ms, months) {
  const d = new Date(ms);
  const day = d.getUTCDate();
  d.setUTCDate(1);
  d.setUTCMonth(d.getUTCMonth() + months);
  const lastDay = new Date(
      Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + 1, 0)).getUTCDate();
  d.setUTCDate(Math.min(day, lastDay));
  return d.getTime();
}

/**
 * The display name for a rent contract's tenant, falling back to the owner.
 *
 * @param {object} c A `contracts` document's data.
 * @return {string} The name to show.
 */
function tenantName(c) {
  return c.party2_name || c.party1_name || "—";
}

/**
 * Formats an installment amount with its currency suffix.
 *
 * @param {object} c A `contracts` document's data.
 * @return {string} e.g. "750,000 د.ع".
 */
function amountLabel(c) {
  const amount = Number(c.rent_amount || 0).toLocaleString("en-US");
  const currency = CURRENCY_LABEL[c.dinar_dolar || c.currency] || "";
  return `${amount} ${currency}`.trim();
}

/**
 * Every alert a single rent contract warrants today.
 *
 * `payment_status` 0 is pending — 1 (received from tenant) and 2 (delivered to
 * owner) are both settled as far as chasing the tenant goes.
 *
 * @param {string} id The contract's document id.
 * @param {object} c The contract's data.
 * @param {number} today Local midnight, epoch ms.
 * @param {boolean} rentAlerts Whether the plan includes rent due/overdue
 *   alerts (the paid `overdue` feature). Expiry alerts are not gated.
 * @return {Array<object>} Candidate notifications.
 */
function candidatesFor(id, c, today, rentAlerts) {
  const out = [];
  const branch = c.branch || "";
  const companyId = c.company_id || "";
  if (!companyId) return out;

  const name = tenantName(c);
  const money = amountLabel(c);

  if (rentAlerts) {
    const soonCutoff = today + DUE_SOON_DAYS * DAY_MS;
    for (const inst of c.installments || []) {
      if ((inst.payment_status || 0) !== 0) continue;
      const due = toMs(inst.due_date);
      if (!due) continue;
      const month = inst.month_number || 0;
      const when = formatDate(due);

      if (due < today) {
        const days = Math.round((today - due) / DAY_MS);
        out.push({
          id: `${id}__rent_overdue__m${month}`,
          type: "rent_overdue",
          companyId, branch, contractId: id, dueDate: inst.due_date,
          title: "کرێی دواکەوتوو",
          body: `${name} — قیستی مانگی ${month} (${money}) ` +
            `${days} ڕۆژە دواکەوتووە. بەرواری ${when}.`,
        });
      } else if (due <= soonCutoff) {
        out.push({
          id: `${id}__rent_due_soon__m${month}`,
          type: "rent_due_soon",
          companyId, branch, contractId: id, dueDate: inst.due_date,
          title: "کرێی نزیک",
          body: `${name} — قیستی مانگی ${month} (${money}) ` +
            `لە ${when} دەبێت وەربگیرێت.`,
        });
      }
    }
  }

  // Lease end is derived from the start date + the agreed term rather than the
  // stored `end_date`, which holds the HANDOVER date (بەرواری ڕادەستکردن), not
  // the end of the term. A contract saved without a term falls back to 12
  // months — the length of the schedule the app always builds.
  const start = toMs(c.start_date);
  if (start) {
    const months = Number(c.rental_period_months) > 0 ?
      Number(c.rental_period_months) : 12;
    const end = addMonths(start, months);
    if (end >= today && end <= today + EXPIRY_DAYS * DAY_MS) {
      const days = Math.round((end - today) / DAY_MS);
      out.push({
        id: `${id}__contract_expiring`,
        type: "contract_expiring",
        companyId, branch, contractId: id, dueDate: new Date(end),
        title: "کۆتایی گرێبەست نزیکە",
        body: `${name} — گرێبەستەکە دوای ${days} ڕۆژ ` +
          `(${formatDate(end)}) کۆتایی دێت.`,
      });
    }
  }

  return out;
}

/**
 * Splits an array into fixed-size chunks.
 *
 * @param {Array} arr Input.
 * @param {number} size Chunk size.
 * @return {Array<Array>} The chunks.
 */
function chunk(arr, size) {
  const out = [];
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
}

/**
 * Whether a member sees a document in [branch]. Mirrors inBranch() in
 * firestore.rules: company-wide admins see every branch, everyone else is
 * confined to their own.
 *
 * @param {object} u A `users` document's data.
 * @param {string} branch The notification's branch.
 * @return {boolean} True when the user should be told.
 */
function userSees(u, branch) {
  if (u.role === "company_admin" && u.branch_admin !== true) return true;
  return (u.branch || "") === branch;
}

/**
 * Runs one full scan. Exported so index.js keeps only the trigger wiring.
 *
 * @param {object} deps Injected Firebase handles.
 * @param {object} deps.db Firestore instance.
 * @param {object} deps.messaging FCM instance.
 * @param {Function} deps.planAllows Feature gate, see index.js.
 * @return {Promise<object>} A small summary, handy in the logs.
 */
async function runDueScan({db, messaging, planAllows}) {
  const today = startOfLocalDay(Date.now());

  // Whole-collection scan. Due dates live inside the `installments` array, and
  // Firestore cannot query into one, so there is no narrower read available.
  // Contracts are small text documents, so this is comfortable at the current
  // scale; past a few tens of thousands it wants paginating by company.
  const snap = await db.collection("contracts")
      .where("contract_type", "==", "rent").get();

  // Group by tenant first: the plan gate and the recipient list are per
  // company, and resolving them once per contract would be a read storm.
  const byCompany = new Map();
  for (const doc of snap.docs) {
    const data = doc.data();
    const cid = data.company_id;
    if (!cid) continue;
    if (!byCompany.has(cid)) byCompany.set(cid, []);
    byCompany.get(cid).push({id: doc.id, data});
  }

  let created = 0;
  let pushed = 0;

  for (const [companyId, contracts] of byCompany) {
    try {
      const companySnap = await db.collection("companies").doc(companyId).get();
      if (!companySnap.exists) continue;
      const company = companySnap.data();

      // An expired trial is locked out of the product; do not keep nagging it.
      if (company.demo && Date.now() >= toMs(company.demo_expires_at)) continue;

      // Rent due/overdue alerts are the paid `overdue` feature. Contract
      // expiry is not sold separately and reaches every plan.
      const rentAlerts = await planAllows(db, company, "overdue", false);

      const candidates = [];
      for (const {id, data} of contracts) {
        candidates.push(...candidatesFor(id, data, today, rentAlerts));
      }
      if (candidates.length === 0) continue;

      const fresh = await writeNew(db, candidates);
      created += fresh.length;
      if (fresh.length === 0) continue;

      pushed += await pushSummaries(
          db, messaging, companyId, fresh);
    } catch (e) {
      console.error(`Due scan failed for company ${companyId}:`, e);
    }
  }

  const pruned = await prune(db, today);
  console.log(
      `Due scan: ${created} raised, ${pushed} pushed, ${pruned} pruned.`);
  return {created, pushed, pruned};
}

/**
 * Writes the candidates that don't exist yet.
 *
 * @param {object} db Firestore instance.
 * @param {Array<object>} candidates From candidatesFor().
 * @return {Promise<Array<object>>} Only the ones actually created.
 */
async function writeNew(db, candidates) {
  const col = db.collection("notifications");
  const fresh = [];

  for (const group of chunk(candidates, CHUNK)) {
    const refs = group.map((n) => col.doc(n.id));
    const existing = await db.getAll(...refs);
    const batch = db.batch();
    let writes = 0;

    existing.forEach((doc, i) => {
      if (doc.exists) return;
      const n = group[i];
      batch.set(col.doc(n.id), {
        company_id: n.companyId,
        branch: n.branch,
        type: n.type,
        title: n.title,
        body: n.body,
        contract_id: n.contractId,
        due_date: n.dueDate || null,
        created_at: new Date(),
        read_by: [],
      });
      writes++;
      fresh.push(n);
    });

    if (writes > 0) await batch.commit();
  }

  return fresh;
}

/**
 * Sends each member of the company ONE push covering everything new they can
 * see, and cleans up tokens FCM reports as dead.
 *
 * @param {object} db Firestore instance.
 * @param {object} messaging FCM instance.
 * @param {string} companyId The tenant.
 * @param {Array<object>} fresh Newly created notifications.
 * @return {Promise<number>} How many messages were sent.
 */
async function pushSummaries(db, messaging, companyId, fresh) {
  const usersSnap = await db.collection("users")
      .where("company_id", "==", companyId).get();

  // token -> the uid that owns it, so a dead token can be removed from the
  // right document without a second query.
  const owner = new Map();
  const perToken = new Map();

  for (const doc of usersSnap.docs) {
    const u = doc.data();
    const tokens = u.fcm_tokens || [];
    if (tokens.length === 0) continue;
    const mine = fresh.filter((n) => userSees(u, n.branch));
    if (mine.length === 0) continue;
    for (const t of tokens) {
      owner.set(t, doc.id);
      perToken.set(t, mine);
    }
  }
  if (perToken.size === 0) return 0;

  // Identical summaries are sent as one multicast. In practice everyone in a
  // branch shares a payload, so this collapses to one or two sends.
  const byPayload = new Map();
  for (const [token, mine] of perToken) {
    const key = mine.map((n) => n.id).join("|");
    if (!byPayload.has(key)) byPayload.set(key, {mine, tokens: []});
    byPayload.get(key).tokens.push(token);
  }

  const dead = [];
  let sent = 0;

  for (const {mine, tokens} of byPayload.values()) {
    const title = mine.length === 1 ?
      mine[0].title :
      `${mine.length} ئاگادارکردنەوەی نوێ`;
    const body = mine.length === 1 ?
      mine[0].body :
      `${mine[0].body} …`;

    for (const batchTokens of chunk(tokens, TOKEN_CHUNK)) {
      try {
        const res = await messaging.sendEachForMulticast({
          tokens: batchTokens,
          notification: {title, body},
          data: {
            type: mine.length === 1 ? mine[0].type : "summary",
            contract_id: mine.length === 1 ? mine[0].contractId : "",
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
          android: {
            priority: "high",
            notification: {clickAction: "FLUTTER_NOTIFICATION_CLICK"},
          },
        });
        sent += res.successCount;
        res.responses.forEach((r, i) => {
          const code = r.error && r.error.code;
          if (code === "messaging/registration-token-not-registered" ||
              code === "messaging/invalid-registration-token") {
            dead.push(batchTokens[i]);
          }
        });
      } catch (e) {
        console.error(`Push failed for company ${companyId}:`, e);
      }
    }
  }

  // Uninstalled apps and cleared caches leave tokens behind forever otherwise,
  // and every future run pays to send to them.
  if (dead.length > 0) {
    const byUser = new Map();
    for (const t of dead) {
      const uid = owner.get(t);
      if (!uid) continue;
      if (!byUser.has(uid)) byUser.set(uid, []);
      byUser.get(uid).push(t);
    }
    const batch = db.batch();
    for (const [uid, tokens] of byUser) {
      batch.update(db.collection("users").doc(uid), {
        fcm_tokens: FieldValue.arrayRemove(...tokens),
      });
    }
    await batch.commit().catch((e) =>
      console.error("Dead token cleanup failed:", e));
  }

  return sent;
}

/**
 * Deletes notifications past the retention window, capped at one batch a run
 * so a large backlog drains over several days instead of timing out.
 *
 * @param {object} db Firestore instance.
 * @param {number} today Local midnight, epoch ms.
 * @return {Promise<number>} How many were deleted.
 */
async function prune(db, today) {
  const cutoff = new Date(today - RETENTION_DAYS * DAY_MS);
  const old = await db.collection("notifications")
      .where("created_at", "<", cutoff).limit(500).get();
  if (old.empty) return 0;
  const batch = db.batch();
  old.docs.forEach((d) => batch.delete(d.ref));
  await batch.commit();
  return old.size;
}

module.exports = {runDueScan};
