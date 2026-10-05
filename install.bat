@echo off
rem MarioCraft installer: builds MarioCraft from source with your own Super Mario 64 ROM.
rem Needs MSYS2 (https://www.msys2.org, installed to C:\msys64). See README.md.
cd /d "%~dp0"
if not exist "C:\msys64\usr\bin\bash.exe" (
  echo Before MarioCraft can be installed, this PC needs MSYS2 ^(it builds Super Mario 64^).
  echo Opening its download page in your browser...
  echo.
  echo   Download the installer ^(msys2-x86_64-....exe^) and run it.
  echo   Keep the install folder as C:\msys64 ^(the default^).
  echo   When it finishes, untick "Run MSYS2 now", then run install.bat again.
  start "" "https://www.msys2.org/"
  echo.
  pause
  exit /b 1
)
set MSYSTEM=MINGW64
set CHERE_INVOKING=1
"C:\msys64\usr\bin\bash.exe" -l ./install.sh
echo.
pause
