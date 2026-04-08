import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import * as nodemailer from "nodemailer";

admin.initializeApp();
const db = admin.firestore();

// ---------------------------------------------------------------------------
// HELPERS
// ---------------------------------------------------------------------------

/**
 * Generates a cryptographically random password of the given length.
 * Uses only alphanumeric + symbols safe for email display.
 */
function generateSecurePassword(length = 6): string {
  const charset =
    "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789!@#$%";
  const bytes = require("crypto").randomBytes(length);
  let password = "";
  for (let i = 0; i < length; i++) {
    password += charset[bytes[i] % charset.length];
  }
  return password;
}

/**
 * Creates a Nodemailer transporter using Gmail.
 * Set GMAIL_USER and GMAIL_APP_PASSWORD in Firebase secrets / env config.
 */
function createTransporter() {
  const user = functions.config().gmail?.user ?? process.env.GMAIL_USER;
  const pass =
    functions.config().gmail?.app_password ?? process.env.GMAIL_APP_PASSWORD;

  return nodemailer.createTransport({
    service: "gmail",
    auth: { user, pass },
  });
}

// ---------------------------------------------------------------------------
// CLOUD FUNCTION: createMember
// ---------------------------------------------------------------------------
// Called from the iOS Admin Dashboard via FirebaseFunctions SDK.
// Expected input: { email: string }
// Returns:        { success: true, uid: string }
// ---------------------------------------------------------------------------
export const createMember = functions.https.onCall(async (data, context) => {
  // 1. Auth guard – caller must be authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "You must be signed in to perform this action."
    );
  }

  // 2. Role guard – caller must be admin
  const callerDoc = await db
    .collection("users")
    .doc(context.auth.uid)
    .get();

  if (!callerDoc.exists || callerDoc.data()?.role !== "admin") {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Only the admin can create member accounts."
    );
  }

  // 3. Validate input
  const email: string = (data.email ?? "").trim().toLowerCase();
  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "A valid email address is required."
    );
  }

  // 4. Check for duplicate
  try {
    await admin.auth().getUserByEmail(email);
    throw new functions.https.HttpsError(
      "already-exists",
      "An account with this email address already exists."
    );
  } catch (err: any) {
    // getUserByEmail throws 'auth/user-not-found' when email is free — that's fine
    if (err.code !== "auth/user-not-found") {
      throw err; // re-throw unexpected or our own HttpsError
    }
  }

  // 5. Generate a secure random password (never stored in plain text)
  const plainPassword = generateSecurePassword(8); // 8 chars for better security

  // 6. Create Firebase Auth user
  const userRecord = await admin.auth().createUser({
    email,
    password: plainPassword,
    emailVerified: false,
  });

  // 7. Store Firestore document (no plain-text password)
  const now = admin.firestore.FieldValue.serverTimestamp();
  await db.collection("users").doc(userRecord.uid).set({
    email,
    role: "member",
    createdAt: now,
  });

  // 8. Send welcome email with credentials
  try {
    const transporter = createTransporter();
    await transporter.sendMail({
      from: `"DeskHive" <${functions.config().gmail?.user ?? process.env.GMAIL_USER}>`,
      to: email,
      subject: "Welcome to DeskHive – Your Account Details",
      html: buildWelcomeEmail(email, plainPassword),
    });
  } catch (emailError) {
    // Log email failure but don't fail the entire operation
    functions.logger.error("Failed to send welcome email:", emailError);
  }

  return { success: true, uid: userRecord.uid };
});

// ---------------------------------------------------------------------------
// EMAIL TEMPLATE
// ---------------------------------------------------------------------------
function buildWelcomeEmail(email: string, password: string): string {
  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Welcome to DeskHive</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
           background: #f5f5f5; margin: 0; padding: 0; }
    .wrapper { max-width: 560px; margin: 40px auto; background: #ffffff;
               border-radius: 16px; overflow: hidden;
               box-shadow: 0 4px 24px rgba(0,0,0,0.08); }
    .header { background: linear-gradient(135deg, #1A1A2E 0%, #0F3460 100%);
              padding: 40px 32px; text-align: center; }
    .logo-circle { width: 72px; height: 72px; border-radius: 50%;
                   background: linear-gradient(135deg, #E94560, #F5A623);
                   margin: 0 auto 16px; display: flex; align-items: center;
                   justify-content: center; }
    .header h1 { color: #ffffff; margin: 0; font-size: 28px; font-weight: 700; }
    .header p  { color: rgba(255,255,255,0.6); margin: 6px 0 0; font-size: 14px; }
    .body   { padding: 32px; }
    .body p { color: #444; font-size: 15px; line-height: 1.6; margin: 0 0 16px; }
    .cred-box { background: #f8f9fc; border: 1px solid #e0e4ef; border-radius: 12px;
                padding: 20px 24px; margin: 24px 0; }
    .cred-row { display: flex; justify-content: space-between; align-items: center;
                padding: 8px 0; border-bottom: 1px solid #eee; }
    .cred-row:last-child { border-bottom: none; }
    .cred-label { color: #888; font-size: 13px; font-weight: 500; }
    .cred-value { color: #1A1A2E; font-size: 14px; font-weight: 700;
                  font-family: 'Courier New', monospace; }
    .warning { background: #fff8e6; border: 1px solid #f5a623;
               border-radius: 10px; padding: 14px 18px; margin: 20px 0;
               color: #7a5200; font-size: 13px; }
    .footer { background: #f8f9fc; padding: 20px 32px; text-align: center;
              color: #aaa; font-size: 12px; }
  </style>
</head>
<body>
  <div class="wrapper">
    <div class="header">
      <h1>🏢 DeskHive</h1>
      <p>Office Project Management</p>
    </div>
    <div class="body">
      <p>Hi there 👋</p>
      <p>Your DeskHive account has been created by your admin. You can now log in and start collaborating with your team.</p>

      <div class="cred-box">
        <div class="cred-row">
          <span class="cred-label">Email Address</span>
          <span class="cred-value">${email}</span>
        </div>
        <div class="cred-row">
          <span class="cred-label">Temporary Password</span>
          <span class="cred-value">${password}</span>
        </div>
      </div>

      <div class="warning">
        ⚠️ <strong>Important:</strong> Please change your password after your first login to keep your account secure.
      </div>

      <p>If you have any questions, contact your workspace admin.</p>
      <p>Welcome aboard! 🚀</p>
    </div>
    <div class="footer">
      © ${new Date().getFullYear()} DeskHive · Office Project Management System
    </div>
  </div>
</body>
</html>
  `;
}
