const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");
const {buildReceiptHtml} = require("./receipt_html");
const {buildContractHtml} = require("./contract_html");
const {buildExportHtml} = require("./export_html");
const {runDueScan} = require("./due_scan");

admin.initializeApp();

// Cache the embedded fonts (base64) across warm invocations, per family.
// Speda is a Kurdish face; Arabic documents get Amiri, which shapes and
// ligates proper Arabic far better. Both are read lazily so an Arabic-only
// cold start never pays for Speda, and vice versa.
const FONT_FILES = {
  ku: ["SPEDA.ttf", "SPEDA-Bold.ttf"],
  ar: ["Amiri-Regular.ttf", "Amiri-Bold.ttf"],
};
const _fontCache = {};
function fonts(lang) {
  const key = lang === "ar" ? "ar" : "ku";
  if (!_fontCache[key]) {
    const [reg, bold] = FONT_FILES[key];
    _fontCache[key] = {
      fontRegB64: fs
          .readFileSync(path.join(__dirname, "fonts", reg))
          .toString("base64"),
      fontBoldB64: fs
          .readFileSync(path.join(__dirname, "fonts", bold))
          .toString("base64"),
    };
  }
  return _fontCache[key];
}

const CURRENCY_LABEL = {IQD: "دیناری عێراقی", USD: "دۆلاری ئەمریکی"};

// Company logos rarely change — cache the fetched data: URI per URL across
// warm invocations so repeat renders skip the network round-trip.
const LOGO_TTL_MS = 10 * 60 * 1000;
const _logoCache = new Map();

// The renderer only ever embeds images the app itself uploaded to our Storage
// bucket. Anything else is a URL a caller put in the document — attachment_urls
// is member-writable — so fetching it would turn the renderer into an SSRF
// proxy with the function's network position.
const IMAGE_HOSTS = new Set([
  "firebasestorage.googleapis.com",
  "storage.googleapis.com",
  "aqarat-49fc2.firebasestorage.app",
]);

// The response's content-type is remote input and ends up inside a data: URI
// that is interpolated into src="…". An unconstrained value can close the
// attribute and inject markup, so only a known image type is ever emitted.
const IMAGE_MIME = new Set([
  "image/png", "image/jpeg", "image/jpg", "image/webp", "image/gif",
]);

// Attachments are addressed by Storage object path ("contract_docs/<co>/x.jpg")
// so no tokenised download URL — a bearer capability that bypasses Storage
// Rules for anyone who gets the link — ever has to exist. Contracts written
// before that change still hold a full https URL, so pull the object path back
// out of those rather than fetching them over the network.
function objectPathFrom(ref) {
  if (!ref) return "";
  if (!/^https?:/i.test(ref)) return ref.replace(/^\/+/, "");
  let u;
  try {
    u = new URL(ref);
  } catch (e) {
    return "";
  }
  if (!IMAGE_HOSTS.has(u.hostname.toLowerCase())) return "";
  // What getDownloadURL() actually produced:
  // firebasestorage.googleapis.com/v0/b/<bucket>/o/<encoded path>?alt=media&…
  const m = u.pathname.match(/\/o\/(.+)$/);
  if (m) return decodeURIComponent(m[1]);
  const rest = u.pathname.replace(/^\/+/, "");
  // storage.googleapis.com puts the bucket first; <bucket>.firebasestorage.app
  // does not, so only drop a leading segment for the former.
  if (u.hostname.toLowerCase() === "storage.googleapis.com") {
    const parts = rest.split("/");
    return parts.length > 1 ? parts.slice(1).join("/") : "";
  }
  return rest;
}

/**
 * Reads an attachment straight from our bucket with the Admin SDK and returns
 * a data: URI. Never leaves the project's network and needs no token.
 *
 * @param {string} ref Storage object path, or a legacy https download URL.
 * @return {Promise<string>} data: URI, or "" on any failure.
 */
async function attachmentDataUri(ref) {
  const objectPath = objectPathFrom(ref);
  if (!objectPath.startsWith("contract_docs/")) return "";
  try {
    const file = admin.storage().bucket().file(objectPath);
    const [meta] = await file.getMetadata();
    const declared = String(meta.contentType || "").toLowerCase();
    if (!IMAGE_MIME.has(declared)) return "";
    const [buf] = await file.download();
    return `data:${declared};base64,${buf.toString("base64")}`;
  } catch (e) {
    return "";
  }
}

/** Fetches an image URL and returns a data: URI, or "" on any failure. */
async function logoDataUri(url) {
  if (!url) return "";
  let host;
  try {
    const u = new URL(url);
    if (u.protocol !== "https:") return "";
    host = u.hostname.toLowerCase();
  } catch (e) {
    return "";
  }
  if (!IMAGE_HOSTS.has(host)) return "";
  const hit = _logoCache.get(url);
  if (hit && Date.now() - hit.at < LOGO_TTL_MS) return hit.uri;
  try {
    const ctrl = new AbortController();
    const tm = setTimeout(() => ctrl.abort(), 6000);
    const res = await fetch(url, {signal: ctrl.signal, redirect: "error"});
    clearTimeout(tm);
    if (!res.ok) return "";
    const buf = Buffer.from(await res.arrayBuffer());
    const declared = (res.headers.get("content-type") || "")
        .split(";")[0].trim().toLowerCase();
    const mime = IMAGE_MIME.has(declared) ? declared : "image/png";
    const uri = `data:${mime};base64,${buf.toString("base64")}`;
    _logoCache.set(url, {uri, at: Date.now()});
    return uri;
  } catch (e) {
    return "";
  }
}

// Reuse one Chromium across warm invocations — launching it is most of the
// per-call latency, so we keep it alive and only open/close a page each time.
// Single-flight: concurrent callers (boot warm-up + first request) must share
// one launch promise — two parallel @sparticuz/chromium extractions corrupt
// the /tmp binary and every spawn then fails with EFAULT.
let _browserP = null;

function _launchBrowser() {
  return (async () => {
    const chromium = require("@sparticuz/chromium");
    const puppeteer = require("puppeteer-core");
    return puppeteer.launch({
      args: chromium.args,
      executablePath: await chromium.executablePath(),
      headless: chromium.headless,
    });
  })();
}

async function getBrowser() {
  for (;;) {
    if (!_browserP) _browserP = _launchBrowser();
    try {
      const browser = await _browserP;
      if (browser.connected) return browser;
      _browserP = null; // browser died — relaunch on next loop
    } catch (e) {
      _browserP = null;
      throw e;
    }
  }
}

// Warm Chromium while the container is still booting, so the first render
// doesn't also pay the ~3s browser launch. Only in the render* functions'
// instances: this module is shared by ALL functions in the codebase, and
// launching Chromium inside a small 256MiB instance (keepPdfWarm etc.) blows
// its memory limit. K_SERVICE is also absent during deploy-time analysis.
if ((process.env.K_SERVICE || "").toLowerCase().startsWith("render")) {
  getBrowser().catch(() => {});
}

/** Renders an HTML string to a PDF Buffer using headless Chromium. */
async function htmlToPdf(html) {
  const browser = await getBrowser();
  const page = await browser.newPage();
  try {
    // Everything (fonts, logo) is inlined as data: URIs, so "load" is enough;
    // networkidle0 would add a flat 500ms idle wait per render.
    await page.setContent(html, {waitUntil: "load"});
    await page.evaluateHandle("document.fonts.ready");
    // A document may need a measuring pass before it is paginated — the
    // contract uses one to drop its signatures onto the foot of the last page.
    // It has to run here, after the real fonts have arrived, because it
    // depends on where the lines wrap. Documents that define no hook skip it.
    await page.evaluate(() => window.__fitLayout && window.__fitLayout());
    return await page.pdf({format: "A4", printBackground: true});
  } finally {
    await page.close();
  }
}

/**
 * Sets a user's password. Callable only by a Super Admin (verified by their
 * users/{uid}.role == "super_admin"). Direct password setting requires the
 * Admin SDK, so it must run server-side.
 */
exports.setUserPassword = onCall(async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }

  const callerSnap = await admin
      .firestore()
      .collection("users")
      .doc(auth.uid)
      .get();
  if (!callerSnap.exists || callerSnap.data().role !== "super_admin") {
    throw new HttpsError("permission-denied", "Super admin only.");
  }

  const uid = request.data && request.data.uid;
  const newPassword = request.data && request.data.newPassword;
  if (typeof uid !== "string" || uid.length === 0) {
    throw new HttpsError("invalid-argument", "uid is required.");
  }
  if (typeof newPassword !== "string" || newPassword.length < 6) {
    throw new HttpsError(
        "invalid-argument", "Password must be at least 6 characters.");
  }

  await admin.auth().updateUser(uid, {password: newPassword});
  return {ok: true};
});

/**
 * Renders a receipt (پسولە) to a PDF via headless Chromium so Kurdish/Arabic
 * shaping is correct. Takes a saved receipt's id, verifies the caller belongs
 * to the receipt's company, and returns the PDF as base64.
 */
/**
 * Blocks a company whose 7-day trial has run out.
 *
 * The Firestore rules already stop an expired tenant from reading its own
 * data, but these callables run on the Admin SDK, which ignores rules — so the
 * same deadline has to be re-checked here, or the PDF endpoints would keep
 * serving a company the rest of the product has locked out.
 *
 * A company flagged `demo` with no deadline stored counts as expired, matching
 * companyActive() in firestore.rules.
 *
 * @param {object} c Data of the `companies` document.
 * @param {boolean} isSuper Super admins are never blocked.
 */
/**
 * Whether a company's plan (plus its per-company overrides) includes a
 * feature. Mirrors currentPlanFeaturesProvider in the app, but re-checked here
 * because these callables run on the Admin SDK, where the client's gating is
 * just a UI courtesy — a patched client could ask for a paid rendering it did
 * not buy.
 *
 * Defaults are the built-in matrix in plan_config_model.dart. A Super Admin is
 * never gated.
 *
 * @param {object} db Firestore instance.
 * @param {object} company Data of the `companies` document.
 * @param {string} key Feature key, e.g. "arabic_contracts".
 * @param {boolean} isSuper Super admins bypass the check.
 * @return {Promise<boolean>} true when the feature is available.
 */
async function planAllows(db, company, key, isSuper) {
  if (isSuper) return true;
  const overrides = company.feature_overrides || {};
  // An explicit per-company override wins over the plan, either way.
  if (typeof overrides[key] === "boolean") return overrides[key];

  const plan = company.plan || "bronze";
  const snap = await db.collection("config").doc("plans").get();
  const cfg = (snap.exists ? snap.data() : {}) || {};
  const tier = cfg[plan];
  if (tier && typeof tier[key] === "boolean") return tier[key];

  // No stored config yet — fall back to the shipped matrix.
  // Mirrors PlanConfig.defaults in lib/models/plan_config_model.dart.
  const DEFAULT_ON = {
    arabic_contracts: ["gold", "diamond"],
    overdue: ["silver", "gold", "diamond"],
  };
  return (DEFAULT_ON[key] || []).includes(plan);
}

function assertCompanyActive(c, isSuper) {
  if (isSuper || !c.demo) return;
  const at = c.demo_expires_at;
  const ms = at && at.toMillis ? at.toMillis() : 0;
  if (Date.now() >= ms) {
    throw new HttpsError("permission-denied", "Demo period has ended.");
  }
}

exports.renderReceiptPdf = onCall(
    // concurrency 1: each Chromium render gets the instance's full memory.
    // (Add minInstances: 1 to also remove cold starts — it raises the bill.)
    {memory: "1GiB", timeoutSeconds: 120, concurrency: 1},
    async (request) => {
      // Warm-up ping (app screen-open or the keepPdfWarm schedule): just make
      // sure Chromium is running and return — touches no data, so no auth.
      if (request.data && request.data.warmup === true) {
        await getBrowser();
        return {warm: true};
      }

      const auth = request.auth;
      if (!auth) throw new HttpsError("unauthenticated", "Sign in required.");

      const receiptId = request.data && request.data.receiptId;
      if (typeof receiptId !== "string" || !receiptId) {
        throw new HttpsError("invalid-argument", "receiptId is required.");
      }

      const db = admin.firestore();
      const rSnap = await db.collection("receipts").doc(receiptId).get();
      if (!rSnap.exists) {
        throw new HttpsError("not-found", "Receipt not found.");
      }
      const r = rSnap.data();

      // Tenant + branch check: caller must belong to the receipt's company, and
      // (unless they see all branches) to the receipt's branch too — mirrors the
      // Firestore rules so this server-side read path can't bypass them.
      const callerSnap = await db.collection("users").doc(auth.uid).get();
      const caller = callerSnap.data() || {};
      const isSuper = caller.role === "super_admin";
      if (!isSuper && caller.company_id !== r.company_id) {
        throw new HttpsError("permission-denied", "Cross-tenant blocked.");
      }
      const seesAllBranches = isSuper ||
        (caller.role === "company_admin" && caller.branch_admin !== true);
      if (!seesAllBranches && caller.branch !== r.branch) {
        throw new HttpsError("permission-denied", "Cross-branch blocked.");
      }

      const [cSnap, tSnap] = await Promise.all([
        db.collection("companies").doc(r.company_id).get(),
        db.collection("templates").doc(r.company_id).get(),
      ]);
      const c = cSnap.exists ? cSnap.data() : {};
      const t = tSnap.exists ? tSnap.data() : {};
      assertCompanyActive(c, isSuper);

      const company = {
        nameKu: c.name_ku || "",
        phone1: c.phone1 || "",
        phone2: c.phone2 || "",
        address: c.address || "",
        logo_data_uri: await logoDataUri(c.logo_url),
      };
      const receipt = {
        type: r.type,
        receipt_number: r.receipt_number,
        date: r.date && r.date.toDate ? r.date.toDate() : new Date(),
        branch: r.branch || "",
        person_name: r.person_name || "",
        amount: r.amount || 0,
        currency_label: CURRENCY_LABEL[r.dinar_dolar] || "",
        // The code as well as the label: spelling an amount out has to name
        // the subunit (فلس / سەنت), which the label cannot give.
        currency: r.dinar_dolar || "",
        payment_purpose: r.payment_purpose || "",
        note: r.note || "",
        agent_name: r.agent_name || "",
      };
      const template = {
        receipt_color: t.receipt_color || "1E4D8B",
        receipt_font_size: t.receipt_font_size || 10,
      };

      const html = buildReceiptHtml({
        ...fonts(), company, receipt, template, companyId: r.company_id,
      });
      const pdf = await htmlToPdf(html);
      // puppeteer returns a Uint8Array; wrap in Buffer for real base64.
      return {pdf_base64: Buffer.from(pdf).toString("base64")};
    },
);

const toDate = (v) => (v && v.toDate ? v.toDate() : v);

/**
 * Renders a contract (گرێبەست) to a PDF via headless Chromium. Takes a saved
 * contract's id, verifies the caller's company, and returns base64 PDF.
 */
exports.renderContractPdf = onCall(
    {memory: "1GiB", timeoutSeconds: 120, concurrency: 1},
    async (request) => {
      // Warm-up ping — see renderReceiptPdf.
      if (request.data && request.data.warmup === true) {
        await getBrowser();
        return {warm: true};
      }

      const auth = request.auth;
      if (!auth) throw new HttpsError("unauthenticated", "Sign in required.");

      const contractId = request.data && request.data.contractId;
      if (typeof contractId !== "string" || !contractId) {
        throw new HttpsError("invalid-argument", "contractId is required.");
      }

      const db = admin.firestore();
      const kSnap = await db.collection("contracts").doc(contractId).get();
      if (!kSnap.exists) {
        throw new HttpsError("not-found", "Contract not found.");
      }
      const k = kSnap.data();

      const callerSnap = await db.collection("users").doc(auth.uid).get();
      const caller = callerSnap.data() || {};
      const isSuper = caller.role === "super_admin";
      if (!isSuper && caller.company_id !== k.company_id) {
        throw new HttpsError("permission-denied", "Cross-tenant blocked.");
      }
      const seesAllBranches = isSuper ||
        (caller.role === "company_admin" && caller.branch_admin !== true);
      if (!seesAllBranches && caller.branch !== k.branch) {
        throw new HttpsError("permission-denied", "Cross-branch blocked.");
      }

      const [cSnap, tSnap] = await Promise.all([
        db.collection("companies").doc(k.company_id).get(),
        db.collection("templates").doc(k.company_id).get(),
      ]);
      const cd = cSnap.exists ? cSnap.data() : {};
      const t = tSnap.exists ? tSnap.data() : {};
      assertCompanyActive(cd, isSuper);

      // Language of the rendered document. Arabic is a paid feature; the
      // clauses themselves fall back to the shipped Arabic defaults when a
      // company has not customised them.
      const lang = request.data && request.data.lang === "ar" ? "ar" : "ku";
      if (lang === "ar" &&
          !await planAllows(db, cd, "arabic_contracts", isSuper)) {
        throw new HttpsError(
            "permission-denied", "Arabic contracts are not in this plan.");
      }

      const company = {
        nameKu: cd.name_ku || "",
        nameAr: cd.name_ar || "",
        nameEn: cd.name_en || "",
        phone1: cd.phone1 || "",
        phone2: cd.phone2 || "",
        address: cd.address || "",
        logo_data_uri: await logoDataUri(cd.logo_url),
      };
      // Convert the Firestore Timestamps the template tokens read.
      const contract = {
        ...k,
        start_date: toDate(k.start_date),
        end_date: toDate(k.end_date),
        delivery_date: toDate(k.delivery_date),
      };

      // Attachment photos (IDs, deeds…) print as appendix pages when the
      // contract's print_attachments toggle is on.
      let attachments = [];
      if (k.print_attachments !== false && Array.isArray(k.attachment_urls)) {
        attachments = (await Promise.all(
            k.attachment_urls.slice(0, 20).map((u) => attachmentDataUri(u)),
        )).filter(Boolean);
      }

      const html = buildContractHtml({
        ...fonts(lang), contract, company, template: t, attachments,
        companyId: k.company_id, lang,
      });
      const pdf = await htmlToPdf(html);
      return {pdf_base64: Buffer.from(pdf).toString("base64")};
    },
);

/**
 * Renders a company's data export (contracts + receipts tables) to PDF.
 * Super-admin only.
 */
exports.renderExportPdf = onCall(
    {memory: "1GiB", timeoutSeconds: 120, concurrency: 1},
    async (request) => {
      const auth = request.auth;
      if (!auth) throw new HttpsError("unauthenticated", "Sign in required.");

      const db = admin.firestore();
      const callerSnap = await db.collection("users").doc(auth.uid).get();
      if (!callerSnap.exists ||
          callerSnap.data().role !== "super_admin") {
        throw new HttpsError("permission-denied", "Super admin only.");
      }

      const companyId = request.data && request.data.companyId;
      if (typeof companyId !== "string" || !companyId) {
        throw new HttpsError("invalid-argument", "companyId is required.");
      }

      const [cSnap, kQ, rQ] = await Promise.all([
        db.collection("companies").doc(companyId).get(),
        db.collection("contracts").where("company_id", "==", companyId).get(),
        db.collection("receipts").where("company_id", "==", companyId).get(),
      ]);
      const cd = cSnap.exists ? cSnap.data() : {};
      const company = {
        nameKu: cd.name_ku || "",
        nameAr: cd.name_ar || "",
        nameEn: cd.name_en || "",
      };
      const contracts = kQ.docs.map((d) => {
        const k = d.data();
        return {
          ...k,
          start_date: toDate(k.start_date),
          delivery_date: toDate(k.delivery_date),
        };
      });
      const receipts = rQ.docs.map((d) => {
        const r = d.data();
        return {...r, date: toDate(r.date)};
      });

      const html = buildExportHtml({
        ...fonts(), company, contracts, receipts,
      });
      const pdf = await htmlToPdf(html);
      return {pdf_base64: Buffer.from(pdf).toString("base64")};
    },
);

/**
 * Pings the two PDF render functions every 5 minutes with a warmup request
 * so their instances (and Chromium) stay alive — avoids the 10-20s cold
 * start on the first print after an idle period. Costs pennies a month.
 */
exports.keepPdfWarm = onSchedule("every 5 minutes", async () => {
  const base =
    `https://us-central1-${process.env.GCLOUD_PROJECT}.cloudfunctions.net`;
  const ping = (name) =>
    fetch(`${base}/${name}`, {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({data: {warmup: true}}),
    });
  await Promise.allSettled([
    ping("renderReceiptPdf"),
    ping("renderContractPdf"),
  ]);
});

/**
 * Raises the day's rent + lease-expiry alerts and pushes them. 08:00 Baghdad
 * so the office sees them at the start of the working day rather than
 * overnight. See due_scan.js for what it actually does.
 */
exports.scanDueDates = onSchedule(
    {
      schedule: "0 8 * * *",
      timeZone: "Asia/Baghdad",
      timeoutSeconds: 540,
      memory: "512MiB",
    },
    async () => {
      await runDueScan({
        db: admin.firestore(),
        messaging: admin.messaging(),
        planAllows,
      });
    },
);
