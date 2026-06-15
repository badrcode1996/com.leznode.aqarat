const {onCall, HttpsError} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");
const {buildReceiptHtml} = require("./receipt_html");
const {buildContractHtml} = require("./contract_html");

admin.initializeApp();

// Cache the embedded fonts (base64) across warm invocations.
let _fontReg;
let _fontBold;
function fonts() {
  if (!_fontReg) {
    _fontReg = fs
        .readFileSync(path.join(__dirname, "fonts", "SPEDA.ttf"))
        .toString("base64");
    _fontBold = fs
        .readFileSync(path.join(__dirname, "fonts", "SPEDA-Bold.ttf"))
        .toString("base64");
  }
  return {fontRegB64: _fontReg, fontBoldB64: _fontBold};
}

const CURRENCY_LABEL = {IQD: "دیناری عێراقی", USD: "دۆلاری ئەمریکی"};

/** Fetches a logo URL and returns a data: URI, or "" on any failure. */
async function logoDataUri(url) {
  if (!url) return "";
  try {
    const ctrl = new AbortController();
    const tm = setTimeout(() => ctrl.abort(), 6000);
    const res = await fetch(url, {signal: ctrl.signal});
    clearTimeout(tm);
    if (!res.ok) return "";
    const buf = Buffer.from(await res.arrayBuffer());
    const mime = res.headers.get("content-type") || "image/png";
    return `data:${mime};base64,${buf.toString("base64")}`;
  } catch (e) {
    return "";
  }
}

// Reuse one Chromium across warm invocations — launching it is most of the
// per-call latency, so we keep it alive and only open/close a page each time.
let _browser;
async function getBrowser() {
  if (_browser && _browser.connected) return _browser;
  const chromium = require("@sparticuz/chromium");
  const puppeteer = require("puppeteer-core");
  _browser = await puppeteer.launch({
    args: chromium.args,
    executablePath: await chromium.executablePath(),
    headless: chromium.headless,
  });
  return _browser;
}

/** Renders an HTML string to a PDF Buffer using headless Chromium. */
async function htmlToPdf(html) {
  const browser = await getBrowser();
  const page = await browser.newPage();
  try {
    await page.setContent(html, {waitUntil: "networkidle0"});
    await page.evaluateHandle("document.fonts.ready");
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
exports.renderReceiptPdf = onCall(
    // concurrency 1: each Chromium render gets the instance's full memory.
    // (Add minInstances: 1 to also remove cold starts — it raises the bill.)
    {memory: "1GiB", timeoutSeconds: 120, concurrency: 1},
    async (request) => {
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

      // Tenant check: caller must belong to the receipt's company (or super).
      const callerSnap = await db.collection("users").doc(auth.uid).get();
      const caller = callerSnap.data() || {};
      const isSuper = caller.role === "super_admin";
      if (!isSuper && caller.company_id !== r.company_id) {
        throw new HttpsError("permission-denied", "Cross-tenant blocked.");
      }

      const [cSnap, tSnap] = await Promise.all([
        db.collection("companies").doc(r.company_id).get(),
        db.collection("templates").doc(r.company_id).get(),
      ]);
      const c = cSnap.exists ? cSnap.data() : {};
      const t = tSnap.exists ? tSnap.data() : {};

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
        payment_purpose: r.payment_purpose || "",
        note: r.note || "",
        agent_name: r.agent_name || "",
      };
      const template = {
        receipt_color: t.receipt_color || "1E4D8B",
        receipt_font_size: t.receipt_font_size || 10,
      };

      const html = buildReceiptHtml({...fonts(), company, receipt, template});
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
      if (caller.role !== "super_admin" &&
          caller.company_id !== k.company_id) {
        throw new HttpsError("permission-denied", "Cross-tenant blocked.");
      }

      const [cSnap, tSnap] = await Promise.all([
        db.collection("companies").doc(k.company_id).get(),
        db.collection("templates").doc(k.company_id).get(),
      ]);
      const cd = cSnap.exists ? cSnap.data() : {};
      const t = tSnap.exists ? tSnap.data() : {};

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

      const html = buildContractHtml({
        ...fonts(), contract, company, template: t,
      });
      const pdf = await htmlToPdf(html);
      return {pdf_base64: Buffer.from(pdf).toString("base64")};
    },
);
