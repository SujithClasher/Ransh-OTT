/**
 * Ransh OTT — External Subscription Website
 * 
 * Flow:
 * 1. App opens this page in system browser with ?token=<Firebase custom token>
 * 2. This page signs in with the custom token to verify the user
 * 3. User selects a plan → Razorpay Checkout opens
 * 4. On payment success → writes subscription to Firestore
 * 5. App detects subscription via Firestore listener
 */

// ============================================================
// ⚠️  CONFIGURATION — Replace with your actual Firebase config
// ============================================================
const FIREBASE_CONFIG = {
  apiKey: "AIzaSyCEzHmb1mBFJtcDao6CNpG01AjhQArZpEU",
  authDomain: "ransh-ott.firebaseapp.com",
  projectId: "ransh-ott",
  storageBucket: "ransh-ott.firebasestorage.app",
  messagingSenderId: "127984747130",
  appId: "1:127984747130:web:e633db193e714a01f3f1c3",
  measurementId: "G-7LDXKKDFM6",
};

// ⚠️  Replace with your Razorpay Key ID
const RAZORPAY_KEY_ID = "rzp_test_S84YTT1LBy1pFO";

// Plan definitions (must match Firestore/app plans)
const PLANS = {
  monthly: {
    tier: 'monthly',
    name: 'Monthly Premium',
    description: 'Full access for 1 month',
    amountInPaise: 39900, // ₹399
    durationDays: 30,
  },
  lifetime: {
    tier: 'lifetime',
    name: 'Lifetime Access',
    description: 'Pay once, enjoy forever',
    amountInPaise: 599900, // ₹5999
    durationDays: 36500, // ~100 years
  },
};

// ============================================================
// State
// ============================================================
let currentUser = null;

// ============================================================
// Initialize Firebase
// ============================================================
firebase.initializeApp(FIREBASE_CONFIG);
const auth = firebase.auth();
const db = firebase.firestore();

// ============================================================
// DOM Elements
// ============================================================
const loadingOverlay = document.getElementById('loading-overlay');
const authError = document.getElementById('auth-error');
const mainContent = document.getElementById('main-content');
const userEmailEl = document.getElementById('user-email');
const successModal = document.getElementById('success-modal');
const errorModal = document.getElementById('error-modal');
const errorMessage = document.getElementById('error-message');

// ============================================================
// Entry Point
// ============================================================
document.addEventListener('DOMContentLoaded', () => {
  authenticateUser();
});

// ============================================================
// Authentication
// ============================================================
async function authenticateUser() {
  try {
    const urlParams = new URLSearchParams(window.location.search);
    const token = urlParams.get('token');
    const uidFromUrl = urlParams.get('uid'); // Target User ID
    const emailFromUrl = urlParams.get('email');
    const nameFromUrl = urlParams.get('name');
    const phoneFromUrl = urlParams.get('phone');

    // Debugging: Log full URL to ensure params are present
    console.log('Current URL:', window.location.href);

    if (!uidFromUrl) {
      showAuthError('Missing User ID. Please open from the App.');
      return;
    }

    // 1. Sign in effectively to communicate with Firebase
    if (token) {
      const userCredential = await auth.signInWithCustomToken(token);
      currentUser = userCredential.user;
    } else {
      // Fallback: Sign in Anonymously to get a valid auth token for Firestore
      const userCredential = await auth.signInAnonymously();
      // We use the anonymous user to WRITE to the target user's document
      // The Firestore rules now allow this if payment ID is present
      currentUser = userCredential.user;

      // Store the TARGET uid for writes, not the anonymous uid
      currentUser.targetUid = uidFromUrl;

      // Intelligent Name/Email resolution
      const displayName = nameFromUrl || (emailFromUrl ? emailFromUrl.split('@')[0] : 'User');
      const displayIdentifier = emailFromUrl || phoneFromUrl || (nameFromUrl ? `${nameFromUrl} (No Email)` : 'Guest');

      currentUser.displayName = displayName;
      currentUser.email = emailFromUrl; // Store actual email if present
      currentUser.identifier = displayIdentifier; // Custom property for UI
    }

    if (!currentUser) {
      showAuthError('Authentication failed (No user).');
      return;
    }

    // Show main content
    userEmailEl.textContent = currentUser.identifier || 'Guest';
    loadingOverlay.classList.add('hidden');
    mainContent.classList.remove('hidden');

    // Try to load dynamic prices from Firestore
    loadPricesFromFirestore();

  } catch (error) {
    console.error('Auth error:', error);
    showAuthError(`Auth Error: ${error.message}`);
  }
}

function showAuthError(msg) {
  loadingOverlay.classList.add('hidden');
  authError.classList.remove('hidden');

  if (msg) {
    let detail = document.getElementById('auth-error-detail');
    if (!detail) {
      detail = document.createElement('p');
      detail.id = 'auth-error-detail';
      detail.style.cssText = 'color: #ff6b6b; font-size: 14px; margin-top: 10px; font-weight: bold;';
      authError.appendChild(detail);
    }
    detail.textContent = msg;
  }
}

// ============================================================
// Load prices from Firestore (optional — falls back to hardcoded)
// ============================================================
async function loadPricesFromFirestore() {
  try {
    const plansSnap = await db.collection('plans').get();
    plansSnap.forEach(doc => {
      const data = doc.data();
      const tier = data.tier || doc.id;

      if (tier === 'monthly' && data.price_monthly) {
        PLANS.monthly.amountInPaise = data.price_monthly;
        const el = document.getElementById('monthly-price');
        if (el) el.textContent = (data.price_monthly / 100).toLocaleString('en-IN');
      }
      if (tier === 'lifetime' && data.price_monthly) {
        PLANS.lifetime.amountInPaise = data.price_monthly;
        const el = document.getElementById('lifetime-price');
        if (el) el.textContent = (data.price_monthly / 100).toLocaleString('en-IN');
      }
    });
  } catch (e) {
    console.log('Using hardcoded prices (Firestore plans not found):', e.message);
  }
}

// ============================================================
// Plan Selection → Razorpay Checkout
// ============================================================
function selectPlan(planKey) {
  const plan = PLANS[planKey];
  if (!plan) return;

  const targetUid = currentUser.targetUid || currentUser.uid;

  const options = {
    key: RAZORPAY_KEY_ID,
    amount: plan.amountInPaise,
    currency: 'INR',
    name: 'Ransh OTT',
    description: `${plan.name} — ${plan.description}`,
    image: 'logo.png',
    prefill: {
      email: currentUser.email || '',
      name: currentUser.displayName || '',
    },
    theme: {
      color: '#1A1A2E',
    },
    notes: {
      plan_tier: plan.tier,
      user_id: targetUid,
    },
    handler: function (response) {
      // Payment succeeded
      handlePaymentSuccess(response, plan);
    },
    modal: {
      ondismiss: function () {
        console.log('Razorpay checkout dismissed');
      },
    },
  };

  try {
    const rzp = new Razorpay(options);
    rzp.on('payment.failed', function (response) {
      handlePaymentFailure(response.error);
    });
    rzp.open();
  } catch (e) {
    console.error('Razorpay error:', e);
    showError('Could not open payment gateway. Please try again.');
  }
}

// ============================================================
// Payment Success → Write to Firestore
// ============================================================
async function handlePaymentSuccess(response, plan) {
  try {
    const now = new Date();
    const expiresAt = new Date(now.getTime() + plan.durationDays * 24 * 60 * 60 * 1000);

    // Key Fix: Use targetUid (from URL) if available, else fallback to auth uid
    const targetUid = currentUser.targetUid || currentUser.uid;

    if (!targetUid) {
      throw new Error("Target User ID missing");
    }

    // 1. Update user document
    // Note: We are writing to specific fields permissible by the new rules
    await db.collection('users').doc(targetUid).update({ // Changed .set to .update to match rules
      subscription_status: 'active',
      subscription_plan: plan.tier,
      subscription_start: firebase.firestore.Timestamp.fromDate(now),
      subscription_end: firebase.firestore.Timestamp.fromDate(expiresAt),
      razorpay_subscription_id: response.razorpay_order_id || 'one_time_payment',
      last_payment_id: response.razorpay_payment_id,
      updated_at: firebase.firestore.FieldValue.serverTimestamp(),
    });

    // 2. Create subscription record
    await db.collection('subscriptions').add({
      user_id: targetUid, // Store target UID
      user_email: currentUser.email || '',
      plan_tier: plan.tier,
      plan_name: plan.name,
      amount: plan.amountInPaise,
      currency: 'INR',
      razorpay_payment_id: response.razorpay_payment_id,
      razorpay_order_id: response.razorpay_order_id || null,
      razorpay_signature: response.razorpay_signature || null,
      status: 'active',
      started_at: firebase.firestore.Timestamp.fromDate(now),
      expires_at: firebase.firestore.Timestamp.fromDate(expiresAt),
      created_at: firebase.firestore.FieldValue.serverTimestamp(),
      source: 'web',
      auth_uid: currentUser.uid // Track who actually wrote this (anonymous ID)
    });


    // Show success modal
    successModal.classList.remove('hidden');

  } catch (error) {
    console.error('Firestore write error:', error);
    showError('Payment succeeded but subscription activation failed. Please contact support with payment ID: ' + response.razorpay_payment_id);
  }
}

// ============================================================
// Payment Failure
// ============================================================
function handlePaymentFailure(error) {
  console.error('Payment failed:', error);
  const message = error.description || error.reason || 'Payment was declined. Please try again.';
  showError(message);
}

function showError(message) {
  errorMessage.textContent = message;
  errorModal.classList.remove('hidden');
}

function closeErrorModal() {
  errorModal.classList.add('hidden');
}

// ============================================================
// Return to App
// ============================================================
function returnToApp() {
  // Use Android Intent URL — most reliable deep link on Chrome
  const intentUrl = "intent://subscription_success#Intent;scheme=ransh;package=com.ransh.app;end";
  window.location.href = intentUrl;

  // Fallback for non-Chrome browsers: try custom scheme after delay
  setTimeout(() => {
    window.location.href = "ransh://subscription_success";
  }, 500);

  // Final fallback: show manual message
  setTimeout(() => {
    if (successModal) {
      successModal.querySelector('p').textContent =
        'Your subscription is active! Please switch back to the Ransh app manually.';
    }
  }, 2500);
}
