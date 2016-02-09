@echo off
echo [%~nx0] Starting custom batch file ...

set SOLUTION=%1
set BUILDNUMBER=%2
set TARGET=%3

echo.
echo [%~nx0] SOLUTION    : %SOLUTION%
echo [%~nx0] BUILDNUMBER : %BUILDNUMBER%
echo [%~nx0] TARGET      : %TARGET%
