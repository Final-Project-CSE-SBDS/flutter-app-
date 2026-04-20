@echo off
REM Custom ADB wrapper for ECG app - intercepts install commands to use direct method

if "%1"=="install" (
    REM Intercept install command and use direct method
    echo Using direct install method for ECG app...
    for %%i in (%*) do (
        if "%%i"=="C:\FlutterProjects\ecg_flutter_app\build\app\outputs\flutter-apk\app-debug.apk" (
            REM Found the APK path, use direct install
            adb.exe push "%%i" /data/local/tmp/app-debug.apk
            adb.exe shell pm install -r -d /data/local/tmp/app-debug.apk
            goto :eof
        )
    )
)

REM For all other commands, pass through to real ADB
adb.exe %*