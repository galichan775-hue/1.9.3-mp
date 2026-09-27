@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"

set "JAVA_EXE="
set "JAVAW_EXE="
set "JAVA_SOURCE="

rem ============================================================
rem AoH2MP Java 17 launcher v3
rem Robust detection for Oracle JDK and other Java 17 builds.
rem It does NOT rely on a working .jar association.
rem ============================================================

rem 0) Very common Oracle JDK locations first.
call :TryExact "%ProgramFiles%\Java\jdk-17.0.12\bin\java.exe" "Oracle JDK default path"
call :TryExact "%ProgramFiles%\Java\jdk-17\bin\java.exe" "Oracle JDK default path"
call :TryExact "%ProgramFiles(x86)%\Java\jdk-17.0.12\bin\java.exe" "Oracle JDK x86 path"

rem 1) Oracle / JavaSoft registry.
if not defined JAVA_EXE call :TryRegistryRoot "HKLM\SOFTWARE\JavaSoft\JDK"
if not defined JAVA_EXE call :TryRegistryRoot "HKCU\SOFTWARE\JavaSoft\JDK"
if not defined JAVA_EXE call :TryRegistryRoot "HKLM\SOFTWARE\WOW6432Node\JavaSoft\JDK"
if not defined JAVA_EXE call :TryRegistryRoot "HKLM\SOFTWARE\JavaSoft\Java Development Kit"
if not defined JAVA_EXE call :TryRegistryRoot "HKCU\SOFTWARE\JavaSoft\Java Development Kit"
if not defined JAVA_EXE call :TryRegistryRoot "HKLM\SOFTWARE\WOW6432Node\JavaSoft\Java Development Kit"

rem 2) Windows Installed Apps / Uninstall registry.
rem This is the registry source used by the Installed Apps list shown in Windows.
if not defined JAVA_EXE call :TryUninstallRoot "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
if not defined JAVA_EXE call :TryUninstallRoot "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
if not defined JAVA_EXE call :TryUninstallRoot "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"

rem 3) JAVA_HOME.
if not defined JAVA_EXE if defined JAVA_HOME call :TryExact "%JAVA_HOME%\bin\java.exe" "JAVA_HOME"

rem 4) PATH and Oracle javapath shims.
if not defined JAVA_EXE (
  for /f "delims=" %%J in ('where java.exe 2^>nul') do (
    if not defined JAVA_EXE call :CheckJava "%%~fJ" "PATH"
  )
)
if not defined JAVA_EXE call :TryExact "%ProgramFiles%\Common Files\Oracle\Java\javapath\java.exe" "Oracle javapath"
if not defined JAVA_EXE call :TryExact "%ProgramFiles(x86)%\Common Files\Oracle\Java\javapath\java.exe" "Oracle javapath x86"

rem 5) Recursive scan of known Java vendor directories.
rem Unlike the previous launcher this does not depend on wildcard folder naming.
if not defined JAVA_EXE call :ScanDir "%ProgramFiles%\Java" "Program Files Java scan"
if not defined JAVA_EXE call :ScanDir "%ProgramFiles(x86)%\Java" "Program Files x86 Java scan"
if not defined JAVA_EXE call :ScanDir "%ProgramFiles%\Eclipse Adoptium" "Adoptium scan"
if not defined JAVA_EXE call :ScanDir "%ProgramFiles%\Microsoft" "Microsoft JDK scan"
if not defined JAVA_EXE call :ScanDir "%ProgramFiles%\Amazon Corretto" "Corretto scan"
if not defined JAVA_EXE call :ScanDir "%ProgramFiles%\BellSoft" "Liberica scan"
if not defined JAVA_EXE call :ScanDir "%ProgramFiles%\Zulu" "Zulu scan"
if not defined JAVA_EXE call :ScanDir "%ProgramFiles%\Semeru" "Semeru scan"
if not defined JAVA_EXE call :ScanDir "%ProgramFiles%\IBM" "IBM Java scan"
if not defined JAVA_EXE call :ScanDir "%LOCALAPPDATA%\Programs" "LocalAppData Programs scan"
if not defined JAVA_EXE call :ScanDir "%USERPROFILE%\.jdks" "User .jdks scan"
if not defined JAVA_EXE call :ScanDir "%ProgramData%\Oracle\Java" "ProgramData Oracle scan"
if not defined JAVA_EXE call :ScanDir "C:\Java" "C:\Java scan"

if not defined JAVA_EXE goto :NoJava

for %%D in ("%JAVA_EXE%") do set "JAVAW_EXE=%%~dpDjavaw.exe"
if not exist "%JAVAW_EXE%" set "JAVAW_EXE=%JAVA_EXE%"

echo Found Java 17:
echo   %JAVA_EXE%
if defined JAVA_SOURCE echo Source: %JAVA_SOURCE%
echo.

rem Repair .jar launch association for this Windows user.
rem Direct launch below works even if Windows blocks this registry change.
reg add "HKCU\Software\Classes\.jar" /ve /d "AoH2MP.JarFile" /f >nul 2>&1
reg add "HKCU\Software\Classes\AoH2MP.JarFile" /ve /d "Executable JAR File" /f >nul 2>&1
reg add "HKCU\Software\Classes\AoH2MP.JarFile\shell\open\command" /ve /d "\"%JAVAW_EXE%\" -jar \"%%1\" %%*" /f >nul 2>&1

if not exist "%~dp0AoH2MP.jar" goto :NoJar

rem Start the game from its own directory.
start "AoH2MP" /D "%~dp0" "%JAVAW_EXE%" -jar "%~dp0AoH2MP.jar"
exit /b 0

:TryExact
if defined JAVA_EXE exit /b
if "%~1"=="" exit /b
if not exist "%~1" exit /b
call :CheckJava "%~1" "%~2"
exit /b

:TryRegistryRoot
if defined JAVA_EXE exit /b
set "REGROOT=%~1"
if "%REGROOT%"=="" exit /b

rem First ask CurrentVersion when present.
set "REGVER="
for /f "tokens=2,*" %%A in ('reg query "%REGROOT%" /v CurrentVersion 2^>nul ^| findstr /i /c:"CurrentVersion"') do set "REGVER=%%B"
if defined REGVER call :TryRegistryVersion "%REGROOT%" "%REGVER%"
if defined JAVA_EXE exit /b

rem Then enumerate every subkey in case CurrentVersion is missing or stale.
for /f "delims=" %%K in ('reg query "%REGROOT%" 2^>nul ^| findstr /b /i "HKEY_"') do (
  if not defined JAVA_EXE call :TryRegistryKey "%%K"
)
exit /b

:TryRegistryVersion
if defined JAVA_EXE exit /b
set "REGHOME="
for /f "tokens=2,*" %%A in ('reg query "%~1\%~2" /v JavaHome 2^>nul ^| findstr /i /c:"JavaHome"') do set "REGHOME=%%B"
if defined REGHOME call :TryExact "%REGHOME%\bin\java.exe" "JavaSoft registry"
exit /b

:TryRegistryKey
if defined JAVA_EXE exit /b
set "REGHOME="
for /f "tokens=2,*" %%A in ('reg query "%~1" /v JavaHome 2^>nul ^| findstr /i /c:"JavaHome"') do set "REGHOME=%%B"
if defined REGHOME call :TryExact "%REGHOME%\bin\java.exe" "JavaSoft registry"
exit /b

:TryUninstallRoot
if defined JAVA_EXE exit /b
set "UNROOT=%~1"
if "%UNROOT%"=="" exit /b
for /f "delims=" %%K in ('reg query "%UNROOT%" /s /f "Java(TM) SE Development Kit" 2^>nul ^| findstr /b /i "HKEY_"') do (
  if not defined JAVA_EXE call :TryUninstallKey "%%K"
)
rem Also cover OpenJDK vendors shown in Installed Apps.
for /f "delims=" %%K in ('reg query "%UNROOT%" /s /f "JDK 17" 2^>nul ^| findstr /b /i "HKEY_"') do (
  if not defined JAVA_EXE call :TryUninstallKey "%%K"
)
exit /b

:TryUninstallKey
if defined JAVA_EXE exit /b
set "INSTALLDIR="
for /f "tokens=2,*" %%A in ('reg query "%~1" /v InstallLocation 2^>nul ^| findstr /i /c:"InstallLocation"') do set "INSTALLDIR=%%B"
if defined INSTALLDIR call :TryExact "%INSTALLDIR%\bin\java.exe" "Windows Installed Apps registry"
exit /b

:ScanDir
if defined JAVA_EXE exit /b
if "%~1"=="" exit /b
if not exist "%~1" exit /b
for /f "delims=" %%J in ('dir /b /s /a-d "%~1\java.exe" 2^>nul') do (
  if not defined JAVA_EXE call :CheckJava "%%~fJ" "%~2"
)
exit /b

:CheckJava
if defined JAVA_EXE exit /b
set "CANDIDATE=%~1"
if "%CANDIDATE%"=="" exit /b
if not exist "%CANDIDATE%" exit /b

set "VERFILE=%TEMP%\AoH2MP_java_%RANDOM%_%RANDOM%.tmp"
set "JVER="
"%CANDIDATE%" -version >"%VERFILE%" 2>&1
for /f "tokens=3" %%V in ('findstr /i /c:"version" "%VERFILE%" 2^>nul') do if not defined JVER set "JVER=%%~V"
del /q "%VERFILE%" >nul 2>&1

if not defined JVER exit /b
if "%JVER:~0,3%"=="17." (
  set "JAVA_EXE=%CANDIDATE%"
  set "JAVA_SOURCE=%~2"
)
exit /b

:NoJar
cls
echo AoH2MP.jar was not found next to START_AoH2MP.cmd.
echo Extract the whole ZIP before launching the game.
echo.
pause
exit /b 2

:NoJava
cls
echo AoH2MP requires Java 17.
echo.
echo Java 17 was not found automatically even after checking:
echo   - Oracle JavaSoft registry
echo   - Windows Installed Apps registry
echo   - JAVA_HOME and PATH
echo   - Oracle javapath
echo   - recursive scans of common Java installation folders
echo.
echo Your Windows may use a non-standard installation location.
echo Run these two commands in CMD and send the output:
echo   where java
echo   dir /s /b "C:\Program Files\Java\java.exe"
echo.
pause
exit /b 1
