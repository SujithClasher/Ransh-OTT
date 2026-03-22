const functions = require("firebase-functions");
const admin = require("firebase-admin");
const Razorpay = require("razorpay");
const crypto = require("crypto");
const cors = require("cors")({ origin: true });

admin.initializeApp();
const db = admin.firestore();

// Use live keys
const RAZORPAY_KEY_ID = "rzp_live_SJQIUH0i5TtaIs";
const RAZORPAY_SECRET = "RFJwGaqVK6bHvFqRsiig96wE";

const razorpay = new Razorpay({
  key_id: RAZORPAY_KEY_ID,
  key_secret: RAZORPAY_SECRET,
});

exports.createOrder = functions.https.onCall(async (data, context) => {
  try {
    const { amount, receipt, notes } = data;

    if (!amount) {
      throw new functions.https.HttpsError("invalid-argument", "Amount is required");
    }

    const options = {
      amount: amount, // amount in smallest currency unit (paise)
      currency: "INR",
      receipt: receipt || "receipt_" + new Date().getTime(),
      notes: notes || {},
    };

    const order = await razorpay.orders.create(options);
    return order;
  } catch (error) {
    console.error("Error creating order:", error);
    throw new functions.https.HttpsError("internal", error.message || "Unable to create order");
  }
});

exports.verifyPayment = functions.https.onCall(async (data, context) => {
  try {
    const {
      razorpay_order_id,
      razorpay_payment_id,
      razorpay_signature,
      plan_tier,
      plan_name,
      amount,
      target_uid,
      user_email,
      auth_uid,
    } = data;

    if (!razorpay_order_id || !razorpay_payment_id || !razorpay_signature || !target_uid) {
      throw new functions.https.HttpsError("invalid-argument", "Missing required parameters");
    }

    // Verify Signature
    const body = razorpay_order_id + "|" + razorpay_payment_id;
    const expectedSignature = crypto
      .createHmac("sha256", RAZORPAY_SECRET)
      .update(body.toString())
      .digest("hex");

    if (expectedSignature !== razorpay_signature) {
      console.error("Invalid signature:", expectedSignature, "!==", razorpay_signature);
      throw new functions.https.HttpsError("permission-denied", "Invalid payment signature");
    }

    // Signature verified! Save standard subscription data
    const now = new Date();
    // Derive duration: monthly = 30 days, lifetime = 36500 days
    const durationDays = plan_tier === "monthly" ? 30 : 36500;
    const expiresAt = new Date(now.getTime() + durationDays * 24 * 60 * 60 * 1000);

    // 1. Update User Document securely bypassing client rules
    await db.collection("users").doc(target_uid).update({
      subscription_status: "active",
      subscription_plan: plan_tier,
      subscription_start: admin.firestore.Timestamp.fromDate(now),
      subscription_end: admin.firestore.Timestamp.fromDate(expiresAt),
      razorpay_subscription_id: razorpay_order_id,
      last_payment_id: razorpay_payment_id,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 2. Create Subscription Record
    await db.collection("subscriptions").add({
      user_id: target_uid,
      user_email: user_email || "",
      plan_tier: plan_tier,
      plan_name: plan_name,
      amount: amount,
      currency: "INR",
      razorpay_payment_id: razorpay_payment_id,
      razorpay_order_id: razorpay_order_id,
      razorpay_signature: razorpay_signature,
      status: "active",
      started_at: admin.firestore.Timestamp.fromDate(now),
      expires_at: admin.firestore.Timestamp.fromDate(expiresAt),
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      source: "web_cloud_function",
      auth_uid: auth_uid || "",
    });

    return { success: true, message: "Payment verified and subscription activated securely." };
  } catch (error) {
    console.error("Error verifying payment:", error);
    throw new functions.https.HttpsError("internal", error.message || "Failed to process payment data");
  }
});
