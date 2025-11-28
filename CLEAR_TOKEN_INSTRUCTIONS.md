# How to Clear Token/Session Data on Android Phone

## Method 1: Clear App Data (Easiest - No Computer Needed)

### Steps:
1. Open **Settings** on your Android phone
2. Go to **Apps** (or **Application Manager**)
3. Find and tap **ASSANA** app
4. Tap **Storage** (or **Storage & Cache**)
5. Tap **Clear Data** (or **Clear Storage**)
6. Confirm by tapping **OK** or **Clear**

**Result:** All app data including token will be cleared. Next time you open the app, you'll need to login again.

---

## Method 2: Uninstall and Reinstall

### Steps:
1. Long press the **ASSANA** app icon
2. Tap **Uninstall** (or drag to Uninstall)
3. Confirm uninstallation
4. Reinstall the app from Play Store or APK

**Result:** All app data will be removed. Fresh installation.

---

## Method 3: Use Logout Button in App

### Steps:
1. Open the **ASSANA** app
2. Go to **Settings** tab (bottom right icon)
3. Tap **Logout** button
4. Confirm logout

**Result:** Token and session will be cleared. You'll be redirected to login page.

---

## Method 4: Using ADB (For Developers/Testing)

### Prerequisites:
- Phone connected via USB
- USB Debugging enabled
- ADB installed on computer

### Steps:

1. **Find the app package name:**
   ```bash
   adb shell pm list packages | grep assana
   ```
   (Usually something like `com.example.assana` or similar)

2. **Clear app data:**
   ```bash
   adb shell pm clear <package_name>
   ```
   
   Example:
   ```bash
   adb shell pm clear com.example.assana
   ```

3. **Or clear only SharedPreferences:**
   ```bash
   adb shell run-as <package_name> rm -rf /data/data/<package_name>/shared_prefs/
   ```

**Result:** App data cleared. Next app launch will require login.

---

## Method 5: Clear Specific SharedPreferences Keys (Advanced)

If you want to clear only the token without clearing all app data:

```bash
# Connect phone and enable USB debugging
adb shell

# Navigate to app's shared_prefs directory
run-as <package_name>
cd shared_prefs
ls

# Remove the preferences file (usually MainActivity.xml or similar)
rm *.xml

# Or edit the file to remove specific keys
# (More complex, requires root or specific permissions)
```

---

## Quick Test After Clearing

After clearing the token, when you open the app:
- ✅ Should show **Login Page**
- ✅ Should NOT show Home Page directly
- ✅ Should require email and password to login

---

## Troubleshooting

**If app still shows Home Page after clearing:**
1. Force stop the app: Settings → Apps → ASSANA → Force Stop
2. Clear app data again
3. Restart the phone
4. Open the app again

**If you can't find the app in Settings:**
- Some phones have it under "Application Manager" or "Installed Apps"
- Use search function in Settings to find "ASSANA"

