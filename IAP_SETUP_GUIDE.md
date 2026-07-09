# In-App Purchase Setup Guide

## Overview
Neurotrace includes an in-app purchase to unlock High Score Mode for $0.99. This guide explains how to set up the product on Google Play Console.

---

## Product Details

| Field | Value |
|-------|-------|
| **Product ID** | `high_score_mode_unlock` |
| **Product Type** | Non-Consumable |
| **Title** | High Score Mode Unlock |
| **Price** | $0.99 USD |
| **Description** | Unlock endless High Score Mode to compete for the highest score on the leaderboard |

---

## Setup Steps

### 1. Create the Product on Google Play Console

1. Go to [Google Play Console](https://play.google.com/console)
2. Select your **Neurotrace** app
3. Navigate to **Monetize** → **In-app products**
4. Click **Create product**
5. Choose **Non-consumable** product type
6. Enter the **Product ID**: `high_score_mode_unlock` (must match exactly)
7. Fill in the product details:
   - **Default title**: "High Score Mode Unlock"
   - **Default description**: "Unlock endless High Score Mode to compete for the highest score on the leaderboard"

### 2. Set Pricing

1. Under **Pricing and distribution**, select your base country
2. Set the price to **$0.99 USD**
3. The price will auto-convert to other currencies
4. Click **Save**

### 3. Activate the Product

1. Make sure the product status is set to **Active**
2. Save and publish the changes
3. Products typically take a few hours to appear in the Play Store

### 4. Testing Purchases

#### Set Up Test Account
1. Go to **Settings** → **License Testing** in Play Console
2. Add your Google account email(s) to **Test Accounts**
3. Install the build on an Android device signed with your Play Console account

#### Test Purchase Flow
1. Launch the app on the test device
2. Win the game and reach the win screen
3. Click **UNLOCK - $0.99** button
4. You should be prompted to complete the purchase
5. **Note**: Test purchases won't actually charge your account

---

## Code Implementation Details

### Product ID in Code
The app uses the product ID: `high_score_mode_unlock`

Location in code: `lib/main.dart`
- Line: `if (purchase.productID == 'high_score_mode_unlock')`

### Purchase Flow
1. User clicks "UNLOCK - $0.99" on win screen
2. App calls `_purchaseHighScoreMode()`
3. Google Play handles the payment
4. Purchase status is tracked via `InAppPurchase.instance.purchaseStream`
5. On successful purchase:
   - `_highScoreModeUnlocked` is set to `true`
   - Status is saved to `SharedPreferences` with key `'highScoreModeUnlocked'`
   - Button changes to "HIGH SCORE MODE"

### Local Data
Purchase status is stored locally in SharedPreferences:
- **Key**: `'highScoreModeUnlocked'`
- **Type**: Boolean
- **Default**: `false` (not purchased)
- **Persists**: Across app updates and reinstalls

---

## Handling Edge Cases

### Purchase Restoration
The app automatically restores previous purchases on startup via:
```dart
await InAppPurchase.instance.restorePurchases();
```

This ensures users who reinstall the app don't lose their purchase.

### Pending Transactions
If a purchase becomes pending, the app completes it:
```dart
if (purchase.pendingCompleteTransaction) {
  InAppPurchase.instance.completePurchase(purchase);
}
```

### Error Handling
If the purchase fails, users see a snackbar message with the error. The purchase dialog closes and users can try again.

---

## Troubleshooting

### Product Not Appearing in App
- **Cause**: Product hasn't activated yet (takes a few hours)
- **Solution**: Wait and refresh the app

### Test Purchases Not Working
- **Cause**: Device account not added to test accounts
- **Solution**: Add account in Play Console → Settings → License Testing → Test Accounts

### Purchases Not Persisting
- **Cause**: SharedPreferences not saving correctly
- **Solution**: Check logs for SharedPreferences errors; verify app has storage permissions

### Purchase Dialog Not Appearing
- **Cause**: IAP not initialized properly
- **Solution**: Ensure device has Google Play Services installed and updated

---

## Monitoring Purchases

### Via Google Play Console
1. Go to **Monetize** → **In-app products** → **High Score Mode Unlock**
2. View **Revenue reports** to track sales
3. Check **Financial reports** for detailed transaction data

### In-App Analytics
Consider adding custom analytics to track:
- How many users tap the unlock button
- Conversion rate (users who complete purchase / users who tap button)
- Refund rate

---

## Release Checklist

- [ ] Product created in Play Console with ID `high_score_mode_unlock`
- [ ] Product set to Non-Consumable type
- [ ] Price set to $0.99 USD
- [ ] Product is Active and published
- [ ] Tested on device with test account
- [ ] Purchase dialog displays correctly
- [ ] High Score Mode unlocks after purchase
- [ ] Purchase status persists after app restart
- [ ] Purchase restoration works
- [ ] Error messages display properly

---

## Future Enhancements

Consider adding:
- Seasonal discount promotions
- Bundle deals (multiple features)
- Free trial period
- Regional pricing adjustments
- Analytics on purchase patterns
