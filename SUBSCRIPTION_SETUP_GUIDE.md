# MechMinder Monetization & Subscription Guide

This document is your **Master Guide** for adding paying users to your app. It covers the code changes made, how to set up the Google Play Console, and how to verify everything works.

---

## 🚀 Part 1: Code Implementation (What We Changed)

We have already implemented all the necessary code for you. You **do not** need to change any Android/Java/Kotlin code manually.

### 1. New Features Added
*   **Trial System**: The app now tracks the install date. After **15 days**, it considers the trial "Expired".
*   **Paywall Screen**: A premium design screen that pops up when the trial expires or when a user tries to access locked features (like Backup).
*   **Locked Features**: The "Backup & Restore" section in Settings is now locked behind the subscription.
*   **Google Play Billing**: Using the `in_app_purchase` plugin, the app connects directly to Google Play to handle payments.

### 2. Do I need to change Android Code?
**NO.** 
*   We checked your `android/app/build.gradle.kts` file. It is already correctly set up.
*   It has `signingConfigs` configured to read from `key.properties`, which means you are ready to build release versions.
*   The `in_app_purchase` plugin automatically handles all the complex permissions (`com.android.vending.BILLING`) and connection logic.

---

## 🛠️ Part 2: Google Play Console Setup (REQUIRED)

The code will not work until you tell Google about your product.

### Step 1: Set up a Merchant Account
1.  Log in to [Google Play Console](https://play.google.com/console).
2.  Go to **Setup** > **Payments profile**.
3.  Click **Create payments profile** and fill in your bank details (so you can get paid!).

### Step 2: Create the Product
1.  Go to your app in the Console.
2.  Navigate to **Monetize** > **Products** > **In-app products**.
3.  Click **Create product**.
4.  **Product ID**: `lifetime_subscription_79` (Copy this EXACTLY).
5.  **Name**: "Lifetime Premium".
6.  **Description**: "Unlock lifetime access to cloud backups and all features."
7.  **Price**: Click "Set Price" -> Enter **79 INR** -> Apply.
8.  **Status**: Click **Save** and then **Activate**.

---

## 🧪 Part 3: How to Test (Step-by-Step)

**IMPORTANT:** You cannot test payments by just pressing "Run" in VS Code. You must simulate a real download from the Play Store.

### Step 1: Prepare the Build
1.  Open your terminal in VS Code.
2.  Run this command to build a release bundle:
    ```powershell
    flutter build appbundle
    ```
3.  This will create a file at: `build/app/outputs/bundle/release/app-release.aab`.

### Step 2: Upload to Internal Testing
1.  In Google Play Console, go to **Testing** > **Internal testing**.
2.  Click **Create new release**.
3.  Upload the `app-release.aab` file you just built.
4.  Click **Next** and **Save/Publish**. (It usually reviews very quickly, often instantly).

### Step 3: Add Yourself as a Tester
1.  In **Internal testing**, click the **Testers** tab.
2.  Create an email list (if you haven't already) and add your Gmail address.
3.  **Copy the "Join on the web" link** and open it on your phone.
4.  Accept the invite.

### Step 4: Add License Testing (Free Purchase)
To test buying without using real money:
1.  Go to Console Home > **Setup** > **License testing**.
2.  Add your email address to the "License testers" list.
3.  Save.

### Step 5: Test on Device
1.  Download the app using the link from Step 3 (or the Play Store if you successfully joined the beta).
2.  **Open the App**:
    *   **Test Trial**: It should work normally (Day 1).
    *   **Test Paywall**: Go to **Settings** > **Data Management**. Click "Export Backup". The Paywall should appear.
    *   **Test Purchase**: Click "Subscribe Now".
        *   You should see a Google Play sheet saying **"Test Card, always approves"**.
        *   Buy it.
    *   **Verify**: The lock icons should disappear, and you should be able to click Export Backup.

---

## ❓ Frequently Asked Questions

**Q: Why does it say "Product not found"?**
A: This happens if:
1.  You didn't upload the build to the Play Console yet.
2.  The Product ID in Console doesn't match `lifetime_subscription_79`.
3.   The product is "Inactive" in the Console.
4.  You are running a debug build (`flutter run`) that isn't signed with the same key as the Console.

**Q: How do I stick the user in the "Trial Expired" mode to test?**
A: You can force the app to think the trial is over by temporarily changing the code in `lib/service/subscription_provider.dart`.
*   Change `static const int _trialDurationDays = 15;` to `static const int _trialDurationDays = 0;`.
*   Run the app. It will instantly expire. 
*   **Don't forget to change it back before releasing!**

