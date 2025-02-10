@echo off
setlocal EnableDelayedExpansion

:: Script version
set "VERSION=0.0.1"

:: Store initial directory
set "INITIAL_DIR=%CD%"

:: Store user home directory
set "USER_HOME=%USERPROFILE%"

:parse_args
if "%~1"=="" goto help
if "%~1"=="--help" goto help
if "%~1"=="installed" goto installed
if "%~1"=="available" goto available
if "%~1"=="current" goto current
if "%~1"=="version" goto version

:: Check if it's a version tag
echo %~1 | findstr /r /c:"^v[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$" >nul
if %ERRORLEVEL%==0 (
    set "VERSION_TAG=%~1"
    goto install_version
)
echo %~1 | findstr /r /c:"^v[0-9][0-9]*\.[0-9][0-9]*$" >nul
if %ERRORLEVEL%==0 (
    set "VERSION_TAG=%~1"
    goto install_version
)

echo Error: Invalid command or version format '%~1'
echo Use --help for usage information
cd /d "%INITIAL_DIR%"
exit /b 1

:help
echo Usage: %~n0%~x0 ^<command^|version-tag^>
echo.
echo Commands:
echo   installed      List all installed Nim versions
echo   available      List all available Nim versions
echo   current        Show current Nim version
echo   version        Show script version
echo   --help         Show this help message
echo.
echo Parameters:
echo   version-tag    The Nim version to install (e.g., v2.0.14, v2.2.0)
echo.
echo Examples:
echo   %~n0%~x0 v2.0.14     Install Nim version 2.0.14
echo   %~n0%~x0 installed   List installed versions
cd /d "%INITIAL_DIR%"
exit /b 0

:version
echo %VERSION%
cd /d "%INITIAL_DIR%"
exit /b 0

:current
where choosenim >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Error: choosenim not found
    cd /d "%INITIAL_DIR%"
    exit /b 1
)
for /f "tokens=2" %%a in ('choosenim show ^| findstr "Path:"') do set "CURRENT_PATH=%%a"
if defined CURRENT_PATH (
    for /f "tokens=6 delims=\" %%a in ("!CURRENT_PATH!") do echo %%a
) else (
    echo No version currently selected
)
cd /d "%INITIAL_DIR%"
exit /b 0

:installed
echo Installed Nim versions:
if not exist "%USER_HOME%\.choosenim\nimv" (
    echo   No versions found in %USER_HOME%\.choosenim\nimv
    cd /d "%INITIAL_DIR%"
    exit /b 0
)

for /f "tokens=2" %%a in ('choosenim show ^| findstr "Path:"') do set "CURRENT_PATH=%%a"

for /d %%d in ("%USER_HOME%\.choosenim\nimv\v*") do (
    if exist "%%d\Nim\bin\nim.exe" (
        set "VERSION_DIR=%%~nxd"
        if "%%d\Nim"=="!CURRENT_PATH!" (
            echo  * !VERSION_DIR! ^(current^)
        ) else (
            echo    !VERSION_DIR!
        )
    )
)
cd /d "%INITIAL_DIR%"
exit /b 0

:available
echo Getting list of available Nim versions...
set "TEMP_DIR=%TEMP%\nim_temp_%RANDOM%"
mkdir "%TEMP_DIR%"
cd /d "%TEMP_DIR%"

git clone --quiet https://github.com/nim-lang/Nim
if %ERRORLEVEL% neq 0 (
    echo Error: Failed to clone Nim repository
    cd /d "%INITIAL_DIR%"
    rmdir /s /q "%TEMP_DIR%"
    exit /b 1
)

cd Nim
echo Available versions:
git tag | findstr /r "^v"
cd /d "%INITIAL_DIR%"
rmdir /s /q "%TEMP_DIR%"
exit /b 0

:install_version
:: Check if choosenim is installed
where choosenim >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo choosenim not found, installing...
    
    where curl >nul 2>&1
    if %ERRORLEVEL% equ 0 (
        curl https://nim-lang.org/choosenim/init.sh -sSf | sh
    ) else (
        where wget >nul 2>&1
        if %ERRORLEVEL% equ 0 (
            wget -qO- https://nim-lang.org/choosenim/init.sh | sh
        ) else (
            echo Error: Neither curl nor wget found. Please install either curl or wget and try again
            cd /d "%INITIAL_DIR%"
            exit /b 1
        )
    )

    :: Check if installation succeeded
    where choosenim >nul 2>&1
    if %ERRORLEVEL% neq 0 (
        echo Error: choosenim installation appeared to succeed but choosenim command not found
        echo Please ensure choosenim is properly installed and try again
        echo Add %%USERPROFILE%%\.nimble\bin to your PATH
        cd /d "%INITIAL_DIR%"
        exit /b 1
    )
    set "NEEDS_PATH_WARNING=1"
) else (
    echo choosenim is already installed
)

set "CHOOSENIM_DIR=%USER_HOME%\.choosenim\nimv\%VERSION_TAG%"
set "NIM_DIR=%CHOOSENIM_DIR%\Nim"
set "NIM_BIN_PATH=%NIM_DIR%\bin"

if exist "%NIM_BIN_PATH%\nim.exe" (
    echo Nim %VERSION_TAG% is already installed at %NIM_BIN_PATH%
    echo Setting choosenim to use existing Nim build '%NIM_DIR%'...
    choosenim "%NIM_DIR%"
    cd /d "%INITIAL_DIR%"
    exit /b 0
)

echo Installing Nim %VERSION_TAG%...

if not exist "%CHOOSENIM_DIR%" mkdir "%CHOOSENIM_DIR%"
cd /d "%CHOOSENIM_DIR%"

if not exist "Nim" (
    git clone https://github.com/nim-lang/Nim
    if %ERRORLEVEL% neq 0 (
        echo Error: Failed to clone Nim repository
        cd /d "%INITIAL_DIR%"
        exit /b 1
    )
)

cd Nim
git fetch --tags
git tag | findstr /b "%VERSION_TAG%" >nul
if %ERRORLEVEL% neq 0 (
    echo Error: Version tag '%VERSION_TAG%' not found
    echo Available versions:
    git tag | findstr /r "^v"
    cd /d "%INITIAL_DIR%"
    rmdir /s /q "%CHOOSENIM_DIR%"
    exit /b 1
)

git checkout %VERSION_TAG%
call build_all.bat

if exist "%NIM_BIN_PATH%\nim.exe" (
    echo Setting choosenim to use custom Nim build '%NIM_DIR%'...
    choosenim "%NIM_DIR%"
) else (
    echo Error: Nim binary not found at %NIM_BIN_PATH%
    cd /d "%INITIAL_DIR%"
    exit /b 1
)

if defined NEEDS_PATH_WARNING (
    echo.
    echo WARNING: choosenim is not in your PATH
    echo You must ensure that the Nimble bin dir is in your PATH
    echo.
    echo Add this directory to your system environment variables:
    echo     %%USERPROFILE%%\.nimble\bin
    echo.
    echo After adding to PATH, you may need to restart your terminal
)

cd /d "%INITIAL_DIR%"
exit /b 0