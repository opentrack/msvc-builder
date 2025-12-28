@echo off
set path=%~dp0\bin;%path%
vc.cmd busybox.exe sh %~dp0\build-msvc.sh %*
exit /b %ERRORLEVEL%
