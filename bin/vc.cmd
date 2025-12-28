@echo off
set "_vc_tgt=amd64"
set "_vc_ver=18"
call "%~dp0vc0.cmd" %*
exit /b %ERRORLEVEL%
