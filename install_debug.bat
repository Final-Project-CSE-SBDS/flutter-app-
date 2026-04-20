@echo off
echo Installing APK directly to device...
adb push build\app\outputs\flutter-apk\app-debug.apk /data/local/tmp/app-debug.apk
adb shell pm install -r -d /data/local/tmp/app-debug.apk
if %errorlevel% equ 0 (
    echo APK installed successfully. Launching app...
    adb shell am start -n com.example.ecg_monitor/.MainActivity
) else (
    echo APK install failed.
)