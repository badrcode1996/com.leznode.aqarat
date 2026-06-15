const {onCall, HttpsError} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");
const {buildReceiptHtml} = require("./receipt_html");

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

/** Renders an HTML string to a PDF Buffer using headless Chromium. */
async function htmlToPdf(html) {
  const chromium = require("@sparticuz/chromium");
  const puppeteer = require("puppeteer-core");
  const browser = await puppeteer.launch({
    args: chromium.args,
    executablePath: await chromium.executablePath(),
    headless: chromium.headless,
  });
  try {
    const page = await browser.newPage();
    await page.setContent(html, {waitUntil: "networkidle0"});
    await page.evaluateHandle("document.fonts.ready");
    return await page.pdf({format: "A4", printBackground: true});
  } finally {
    await browser.close();
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
    {memory: "1GiB", timeoutSeconds: 120},
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
      return {pdf_base64: pdf.toString("base64")};
    },
);
