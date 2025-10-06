# Google Sign-In and Firebase Issues Fix

## Issues Fixed:

### 1. Firebase In-App Messaging Cache Error
**Error**: `I/FIAM.Headless: Recoverable exception while reading cache: /data/user/0/com.example.parts/files/fiam_impressions_store_file: open failed: ENOENT (No such file or directory)`

**Fix Applied**:
- Added `android:allowBackup="true"` and `android:dataExtractionRules="@xml/data_extraction_rules"` to AndroidManifest.xml
- Created `android/app/src/main/res/xml/data_extraction_rules.xml` to handle Firebase In-App Messaging cache files

### 2. Google Sign-In API Exception 10
**Error**: `Error signing in with Google: PlatformException(sign_in_failed, com.google.android.gms.common.api.ApiException: 10: , null, null)`

**Root Cause**: API Exception 10 typically indicates SHA-1 fingerprint configuration issues in Firebase Console.

## Required Actions:

### 1. Firebase Console Configuration
You need to add the following SHA-1 fingerprint to your Firebase project:

**Debug SHA-1 Fingerprint**: `33:59:2A:46:48:16:6A:BD:D8:8F:71:DD:F5:F5:3A:5C:E3:DD:F0:C7`

**Steps to add SHA-1 to Firebase**:
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `anime-97d2d`
3. Go to Project Settings (gear icon)
4. Scroll down to "Your apps" section
5. Find your Android app with package name: `com.example.parts`
6. Click on the app
7. Scroll down to "SHA certificate fingerprints"
8. Click "Add fingerprint"
9. Paste the SHA-1 fingerprint: `33:59:2A:46:48:16:6A:BD:D8:8F:71:DD:F5:F5:3A:5C:E3:DD:F0:C7`
10. Click "Save"
11. Download the updated `google-services.json` file
12. Replace the current `android/app/google-services.json` with the new one

### 2. Code Improvements Applied
- Added proper scopes to GoogleSignIn: `['email', 'profile']`
- Enhanced error handling with specific error messages for different Google Sign-In error codes
- Improved Firebase In-App Messaging cache handling

### 3. For Production Release
When you create a release APK, you'll need to:
1. Generate the SHA-1 fingerprint for your release keystore
2. Add that SHA-1 fingerprint to Firebase Console as well
3. Download the updated `google-services.json`

## Testing
After applying the Firebase Console changes:
1. Clean and rebuild the app: `flutter clean && flutter build apk --debug`
2. Test Google Sign-In functionality
3. Check that Firebase In-App Messaging cache errors are resolved

## Files Modified:
- `android/app/src/main/AndroidManifest.xml` - Added backup and data extraction rules
- `android/app/src/main/res/xml/data_extraction_rules.xml` - Created for Firebase cache handling
- `lib/login_page/login_page.dart` - Enhanced Google Sign-In configuration and error handling
- `lib/login_page/sign_up.dart` - Enhanced Google Sign-In configuration

## Important Notes:
- The Firebase Console configuration is the most critical step
- Make sure to download and replace the `google-services.json` file after adding the SHA-1 fingerprint
- Test on a real device or emulator with Google Play Services installed


