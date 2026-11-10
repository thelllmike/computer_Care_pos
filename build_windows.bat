@echo off
REM ============================================================
REM  CP POS - build the Windows app (double-click this file)
REM  Needs: Flutter + Visual Studio "Desktop development with C++"
REM  Optional: Inno Setup 6 (https://jrsoftware.org/isdl.php) for the installer
REM ============================================================
cd /d "%~dp0"
echo.
echo === 1/3  Getting packages ===
call flutter pub get || goto :fail

echo.
echo === 2/3  Building Windows app (takes a few minutes) ===
call flutter build windows --release || goto :fail

if not exist dist mkdir dist
powershell -NoProfile -Command "Compress-Archive -Force -Path 'build\windows\x64\runner\Release\*' -DestinationPath 'dist\CP_POS_Windows.zip'"

echo.
echo === 3/3  Making installer ===
set ISCC="%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
if exist %ISCC% (
  %ISCC% /Q windows\installer\cp_pos.iss || goto :fail
  echo Installer:  %~dp0dist\CP_POS_Setup.exe
) else (
  echo Inno Setup not installed - skipping installer. The ZIP still works.
)

echo.
echo DONE.
echo   Portable app:  %~dp0dist\CP_POS_Windows.zip  (unzip, run cp_pos.exe)
echo   App folder:    %~dp0build\windows\x64\runner\Release\cp_pos.exe
explorer dist
pause
exit /b 0

:fail
echo.
echo *** BUILD FAILED - copy the red error lines above and send them ***
pause
exit /b 1
