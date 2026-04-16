---
title: Bluetooth LE Implementation - Complete Guide
type: documentation
version: 2.0
date: April 2026
---

# Bluetooth LE (BLE) Implementation Guide

This guide explains the improved Bluetooth implementation for the ECG Monitor app and how to fix common connection issues.

## 📋 What's New

The Bluetooth service has been completely rewritten with:

✅ **Robust Scanning**
- RSSI (signal strength) filtering
- Displays all discoverable BLE devices
- Sorted by signal strength
- Discovery logging

✅ **Proper Connection Handling**
- Automatic service/characteristic discovery
- Writable characteristic detection
- Notify/indicate support
- Comprehensive error logging

✅ **Service Discovery**
- Lists all GATT services
- Shows all characteristics UUID
- Identifies read/write capabilities
- Displays properties (notify, indicate, etc.)

✅ **Data Transmission**
- Sends ECG predictions via BLE write
- Supports both write modes
- UTF-8 encoding
- Error feedback

✅ **Fallback Mode**
- Receiver service for second phone
- Alternative connection methods
- Detailed debugging logs

## 🚀 Quick Start

### 1. Enable Bluetooth on Smartwatch

**Smart Watch Setup:**
- Power on your smartwatch
- Go to Settings → Bluetooth
- Enable Bluetooth
- Make device discoverable (usually for 5 minutes)
- Ensure it's within 10 meters of phone

### 2. Open Bluetooth Screen

In the app:
1. Tap the ⚙️ settings or device icon
2. Navigate to "Connect to Smartwatch"
3. Wait for screen to load

### 3. Scan for Devices

1. Tap **"Scan Devices"** button
2. Wait 10 seconds while app scans
3. Devices appear sorted by signal strength (📶 = best signal)

### 4. Select Your Device

- Tap device name from list
- App attempts connection
- Status updates show progress

If connection succeeds:
- Status shows ✅ Connected
- Device name appears
- You can now send ECG data

## 🔍 How RSSI (Signal Strength) Works

The discovery log shows signal indicators:

```
📶      = Excellent (-50 dBm or better)  ✅ Best connection
📶📶    = Very Good (-60 dBm)             ✅ Good
📶📶📶  = Good (-70 dBm)                  ⚠️  May disconnect
📶📶📶📶 = Fair (-80 dBm)                 ⚠️  Unstable
📶🔴    = Poor (worse than -80 dBm)      ❌ Avoid
```

**Move device closer** if signal is poor!

## 🛠️ Troubleshooting

### Problem 1: Device Not Appearing in Scan

**Causes:**
- Smartwatch Bluetooth is OFF
- Device is not in discoverable mode
- Device is too far away (>10m)
- Device already paired (some devices hide when paired)

**Solutions:**
```
1. On smartwatch:
   - Go to Settings → Bluetooth
   - Turn OFF Bluetooth
   - Turn it back ON
   - Set to "Discoverable" or "Visible" mode
   
2. On phone:
   - Make sure Bluetooth is ON
   - Try scanning again
   - Move closer to watch (within 5m)
   
3. Clear old pairings:
   - Forget device from phone Bluetooth settings
   - Restart both devices
   - Try pairing again
```

### Problem 2: Connection Fails

**Error Messages & Solutions:**

```
❌ "Bluetooth is off"
└─ Solution: Enable Bluetooth in Android settings

❌ "No devices found"
└─ Check:
   - Watch Bluetooth is enabled
   - Watch is in discoverable mode
   - RSSI signal is strong enough

❌ "Connection timed out"
└─ Solution:
   - Move phone closer to watch
   - Check watch Bluetooth firmware is updated
   - Try forgetting and re-pairing

❌ "No writable characteristic found"
└─ Solution: Watch may not support BLE write
   └─ Use fallback receiver mode (see below)
```

### Problem 3: Data Not Sending

If connected but predictions not sending:

```
Check in app:
1. Device shows ✅ Connected
2. Tap "Bluetooth" screen
3. Look at "Discovery Log" section
4. Search for:
   - "Found writable characteristic"
   - "Can send data: YES"

If not found:
├─ Watch doesn't support BLE write
├─ Try reconnecting
└─ Use fallback receiver mode
```

## 🔄 Using Fallback Receiver Mode

If smartwatch doesn't support BLE write, use a second Android phone as receiver:

### Setup Receiver Phone

1. Install ECG Monitor app on second phone
2. Open app on second phone
3. Go to "Receiver Mode" (if available)
4. Phone enters listening mode

### Sending from Main Phone

1. Go back to main phone
2. Go to Bluetooth screen
3. App detects "Receiver Mode" device
4. Connect to receiver phone
5. ECG predictions now send to phone instead of watch

## 📊 Understanding the Discovery Log

The app shows detailed connection logs:

```
[12:34:56] Bluetooth is ON
[12:34:57] Starting BLE scan with RSSI filtering...
[12:34:58] 📱 Found device: MyWatch (RSSI: -55 dBm)
[12:34:59] 🔗 Attempting to connect to MyWatch...
[12:35:01] ✅ Connected successfully
[12:35:02] Service discovery in progress...
[12:35:03] ✅ Found 4 service(s)
[12:35:04] 📦 Service: 00001800-0000...
[12:35:05] ✓ Found writable characteristic
```

**Green checkmarks (✓)** = Good
**Warnings (⚠️)** = May not work
**Red X (❌)** = Problem occurred

## 🔧 Technical Details

### GATT Services Supported

The app looks for standard GATT services:

```
Known Services:
├─ Generic Access (00001800...)
├─ Device Information (0000180a...)
├─ Battery Service (0000180f...)
├─ Nordic UART (6e400001...) ← Most smartwatches
└─ Custom Services (device-specific)
```

### Characteristic Properties

The app searches for characteristics with:

```
Write Modes:
├─ Write (with response) - Safer, slower
└─ Write Without Response - Faster, for streaming

Read Modes:
├─ Notify - Device pushes updates
└─ Indicate - Requires acknowledgment
```

## 🐛 Debug Logging

All actions are logged with prefixes:

```
🔵 BLE:   Normal operations
🟡 BLE:   Warnings (may be issues)
🔴 BLE:   Errors (something failed)
🟢 ✓:     Success
```

Check Android Logcat to see detailed logs:

```bash
# In Terminal/VS Code:
flutter logs | grep "BLE"
```

## Android Permissions

The app has these permissions in `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

**Note:** On Android 12+, these permissions must be granted at:
- Settings → Apps → ECG Monitor → Permissions

## 📱 Supported Devices

The implementation supports:

✅ **Most Smartwatches:**
- Wear OS watches
- Fitbit
- Samsung Galaxy Watch
- Garmin watches
- Generic BLE-enabled watches

✅ **Second Android Phones** (Fallback mode)

⚠️ **May Not Work:**
- Old Bluetooth (not BLE/Bluetooth 4.0+)
- Devices without write capability
- Proprietary protocols not using standard GATT

## 📚 Code Architecture

```
lib/services/
├── bluetooth_service.dart           ← Main BLE implementation
├── bluetooth_receiver_service.dart  ← Fallback receiver mode
└── permission_service.dart          ← Permission handling

lib/screens/
├── bluetooth_screen.dart            ← Connection UI
└── home_screen.dart                 ← ECG prediction → BLE send
```

## 🔗 API Reference

### BluetoothService

```dart
// Scan for devices
await _bluetoothService.startScan(timeout: Duration(seconds: 10));

// Connect to device
await _bluetoothService.connectToDevice(device);

// Send prediction
await _bluetoothService.sendPredictionResult(
  label: "NORMAL",
  confidence: 99.5,
  includeConfidence: true,
);

// Register callbacks
_bluetoothService.onDeviceFound((device, rssi) {
  // Handle device found
});

_bluetoothService.onConnectionState((state) {
  // Handle connection state change
});

_bluetoothService.onServicesDiscovered((services) {
  // Handle services discovered
});
```

## 🚨 Common Error Messages

| Error | Cause | Fix |
|-------|-------|-----|
| `Connection timed out` | Device too far or unreachable | Move closer, restart |
| `No services found` | Device not compatible | Try different device |
| `No writable characteristic` | Device read-only | Use receiver mode |
| `Bluetooth is off` | Bluetooth disabled | Enable Bluetooth |
| `Insufficient permissions` | Android permissions denied | Grant permissions |

## ✅ Verification Checklist

Before assuming it's broken, verify:

- [ ] Smartwatch has Bluetooth enabled
- [ ] Smartwatch is in discoverable mode
- [ ] Phone and watch are within 10 meters
- [ ] Phone's Bluetooth is enabled
- [ ] App has permission to use Bluetooth (Android 12+)
- [ ] Device appears in scan results
- [ ] RSSI is -90dBm or better
- [ ] Connection status shows ✅ Connected
- [ ] Discovery log shows writable characteristic found
- [ ] ECG predictions are being generated

## 📞 Still Having Issues?

1. **Check the Discovery Log** - most info is there
2. **Review error messages** - they're descriptive
3. **Restart both devices** - fixes many transient issues
4. **Try a different watch** - if available
5. **Check Android version** - needs 5.0+ (API 21+)

## 🔜 Future Improvements

Planned enhancements:
- [ ] Full GATT server mode for fallback
- [ ] Multiple device support
- [ ] Persistent device pairing
- [ ] Automatic reconnection
- [ ] RSSI-based filtering UI
- [ ] Advanced debug tools

---

**Last Updated:** April 2026
**Tested On:** Android 10, 12, 13
**Flutter Version:** 3.x
**flutter_blue_plus:** 1.36.8+
