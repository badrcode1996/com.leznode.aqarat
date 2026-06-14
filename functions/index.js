const {onCall, HttpsError} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();

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
