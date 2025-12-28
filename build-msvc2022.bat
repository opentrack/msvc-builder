@echo off
set path=%~dp0\bin;%path%
vc2022.cmd busybox.exe sh %~dp0\build-msvc.sh %*
exit /b %ERRORLEVEL%
