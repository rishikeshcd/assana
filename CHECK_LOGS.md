# How to Check App Logs on Android Device

## Prerequisites

1. **Enable USB Debugging on your phone:**
   - Go to Settings → About Phone
   - Tap "Build Number" 7 times to enable Developer Options
   - Go back to Settings → Developer Options
   - Enable "USB Debugging"
   - Connect your phone to your computer via USB cable

2. **Install ADB (Android Debug Bridge):**
   - If you have Flutter installed, ADB is usually already included
   - ADB is located in: `C:\Users\YourUsername\AppData\Local\Android\Sdk\platform-tools\`
   - Or download Android Platform Tools from: https://developer.android.com/studio/releases/platform-tools

## Steps to Check Logs

### On Windows (PowerShell or Command Prompt):

1. **Open PowerShell or Command Prompt**

2. **Navigate to the ADB directory** (if ADB is not in your PATH):
   ```powershell
   cd C:\Users\YourUsername\AppData\Local\Android\Sdk\platform-tools
   ```

3. **Check if your device is connected:**
   ```powershell
   adb devices
   ```
   - You should see your device listed
   - If you see "unauthorized", check your phone and allow USB debugging

4. **View all logs:**
   ```powershell
   adb logcat
   ```

5. **Filter logs for appointments (recommended):**
   ```powershell
   adb logcat | Select-String -Pattern "Filtering appointments|Appointment date|Parsed dateTime|Error parsing|HomePage|booking_time"
   ```

   Or using grep (if you have Git Bash or WSL):
   ```bash
   adb logcat | grep -E "Filtering appointments|Appointment date|Parsed dateTime|Error parsing|HomePage|booking_time"
   ```

6. **Clear old logs and start fresh:**
   ```powershell
   adb logcat -c
   adb logcat | Select-String -Pattern "HomePage|Appointment|booking"
   ```

7. **Save logs to a file:**
   ```powershell
   adb logcat > app_logs.txt
   ```
   Then open `app_logs.txt` in a text editor and search for relevant messages.

## Method 2: Using Flutter DevTools (Easier)

1. **Run your app in debug mode:**
   ```powershell
   flutter run
   ```

2. **Open DevTools:**
   - Press `d` in the terminal, or
   - Open browser to: http://localhost:9100 (or the URL shown in terminal)

3. **Go to Logging tab** in DevTools
   - You'll see all logs there
   - You can filter by searching for "HomePage", "Appointment", etc.

## Method 3: Using Android Studio / VS Code

### In VS Code:
1. Open the Debug Console (View → Debug Console)
2. When running the app, logs will appear there
3. Use the search box to filter logs

### In Android Studio:
1. Open Logcat tab at the bottom
2. Filter by package name: `com.your.package.name`
3. Search for: "HomePage", "Appointment", "booking_time"

## Method 4: Check Logs Directly on Phone (No Computer Needed)

1. **Install a log viewer app** from Play Store:
   - "Log Viewer" or "Logcat Reader"
   - Note: These apps may require root access for full functionality

2. **Or use Flutter's built-in logging:**
   - The app already prints logs using `print()` statements
   - These logs are visible in the console when running `flutter run`

## Quick Test Commands

**Check if device is connected:**
```powershell
adb devices
```

**View Flutter/Dart logs only:**
```powershell
adb logcat | Select-String -Pattern "flutter"
```

**View all logs and save to file:**
```powershell
adb logcat > logs.txt
```

**Clear logs and start monitoring:**
```powershell
adb logcat -c
adb logcat | Select-String -Pattern "HomePage|Appointment|Error"
```

## Troubleshooting

- **"adb: command not found"**: Add ADB to your PATH or use full path
- **"device unauthorized"**: Check phone and allow USB debugging
- **No logs appearing**: Make sure the app is running and you're filtering correctly
- **Too many logs**: Use more specific filters or save to file and search

## What to Look For

When checking logs, look for these messages:
- `🔍 Filtering appointments for today:`
- `📋 Total appointments:`
- `Appointment date:`
- `Parsed dateTime (Local):`
- `Error parsing booking_time`
- `⚠️ Appointment date "X" does not match today "Y"`

These will help identify why appointments aren't showing on that specific device.

