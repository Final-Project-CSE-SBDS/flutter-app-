@echo off
REM Override ADB install to use direct method for this project
set ORIGINAL_ADB=%PATH%
set PATH=%~dp0scripts;%PATH%
flutter %*