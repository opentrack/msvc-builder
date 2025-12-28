@echo off
set "VSPATH="

:: The double-double quotes fix the "C:\Program" space issue
for /f "usebackq tokens=*" %%I in (`^""%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -products * -version "%_vc_ver%" -property installationPath^"`) do (
  set "VSPATH=%%I"
)

:: FIX: Use 'if not defined' and GOTO to avoid the poison character ')' breaking the script
if not defined VSPATH goto :error_missing

:: Call vcvarsall
call "%VSPATH%\VC\Auxiliary\Build\vcvarsall.bat" %_vc_tgt% >nul 2>&1 || exit /b %ERRORLEVEL%

:: Run the command passed as arguments
%*
exit /b %ERRORLEVEL%

:error_missing
echo Visual Studio version %_vc_ver% not found.
exit /b 1
