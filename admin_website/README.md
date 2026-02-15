# Ransh OTT - Subscription Website

This website handles subscription payments via Razorpay to avoid Google Play Store commissions (0% vs 30%).

## Deployment

Deploy to Firebase Hosting:
```bash
firebase login
firebase deploy --only hosting
```

## Configuration

Update `app.js` if you change your Firebase project or Razorpay keys:

- `FIREBASE_CONFIG`: From Firebase Console → Project Settings
- `RAZORPAY_KEY_ID`: From Razorpay Dashboard (use Live key for production)

## How It Works

1. App opens `https://ransh-ott.web.app/?uid=XXX&email=XXX`
2. Website verifies user (optional custom token or basic params)
3. User pays via Razorpay Checkout
4. Website writes subscription data to Firestore (`users/{uid}` and `subscriptions/`)
5. App detects change in Firestore and unlocks content
