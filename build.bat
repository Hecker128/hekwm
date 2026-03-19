:: Main build script for HEKWM.

set SCRIPT="main.ahk"
set ICON="assets\icon.ico"
set AHK2EXE="C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe"
set AHK_BASE="C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"

if not exist "bin" mkdir "bin"

%AHK2EXE% /in %SCRIPT% /out "bin\hekwm.exe" /base %AHK_BASE% /icon %ICON%
exit /b %ERRORLEVEL%
