@echo off
rem Entry point for cmd.exe. Everything lives in ee (POSIX sh); ee.ps1 only
rem picks a shell to run it with.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ee.ps1" %*
