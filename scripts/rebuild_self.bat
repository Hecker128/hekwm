:: Script for HEKWM to "re-build itself".

:: Set the working directory to the first command-line-argument.
cd %1

:: Sleep for 1 second to give the old executable time to do exitapp.
timeout /t 1

move "bin\hekwm.exe" "bin\hekwm.exe.old"
call build.bat

:: If the build is unsuccessfull, restore the old executable.
if %ERRORLEVEL% NEQ 0 (
	set ERRORLEVEL_BUILD=%ERRORLEVEL%
	move "bin\hekwm.exe.old" "bin\hekwm.exe"
	start "" "bin\hekwm.exe"
	exit /b %ERRORLEVEL_BUILD%
)

:: If the build is successfull, delete the old executable and run the new one.
del "bin\hekwm.exe.old"
start "" "bin\hekwm.exe"
exit /b 0
