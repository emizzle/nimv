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
if "%~1"=="--version" goto version

:: Check if it's a version number
echo %~1 | findstr /r "^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$" >nul
if %ERRORLEVEL%==0 (
    set "VERSION_NUM=%~1"
    set "VERSION_TAG=v%~1"
    goto install_version
)
echo %~1 | findstr /r "^[0-9][0-9]*\.[0-9][0-9]*$" >nul
if %ERRORLEVEL%==0 (
    set "VERSION_NUM=%~1"
    set "VERSION_TAG=v%~1"
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
echo   --version      Show script version
echo   --help         Show this help message
echo.
echo Parameters:
echo   version-tag    The Nim version to install (e.g., 2.0.14, 2.2.0)
echo.
echo Examples:
echo   %~n0%~x0 2.0.14     Install Nim version 2.0.14
echo   %~n0%~x0 installed   List installed versions
cd /d "%INITIAL_DIR%"
exit /b 0

:version
echo %VERSION%
cd /d "%INITIAL_DIR%"
exit /b 0

:current
set "nim_exe=%USER_HOME%\.nimble\bin\nim.exe"
if exist "%nim_exe%" (
    for /f "tokens=*" %%i in ('dir /a:l "%nim_exe%" ^| find "["') do (
        set "target=%%i"
        set "target=!target:*[=!"
        set "target=!target:]=!"
        for /f "tokens=6 delims=\" %%a in ("!target!") do (
            echo %%a
            cd /d "%INITIAL_DIR%"
            exit /b 0
        )
    )
)
echo No version currently selected
cd /d "%INITIAL_DIR%"
exit /b 0

:installed
echo Installed Nim versions:

:: Get current version path
set "current_path="
set "nim_exe=%USER_HOME%\.nimble\bin\nim.exe"
if exist "%nim_exe%" (
    for /f "tokens=*" %%i in ('dir /a:l "%nim_exe%" ^| find "["') do (
        set "current_path=%%i"
        set "current_path=!current_path:*[=!"
        set "current_path=!current_path:]=!"
    )
)

:: Create temporary file for sorting
set "temp_file=%TEMP%\nim_versions.txt"
if exist "%temp_file%" del "%temp_file%"

:: Collect versions
if exist "%USER_HOME%\.nimv" (
    for /d %%d in ("%USER_HOME%\.nimv\*") do (
        if exist "%%d\Nim\bin\nim.exe" (
            for /f "tokens=*" %%v in ("%%~nxd") do (
                echo %%v>>"%temp_file%"
            )
        )
    )

    :: Sort versions and display
    if exist "%temp_file%" (
        for /f "tokens=*" %%v in ('type "%temp_file%" ^| sort') do (
            set "version_path=%USER_HOME%\.nimv\%%v\Nim\bin\nim.exe"
            if "!version_path!"=="!current_path!" (
                echo  * %%v (current^)
            ) else (
                echo    %%v
            )
        )
        del "%temp_file%"
    ) else (
        echo   No versions found in %USER_HOME%\.nimv
    )
) else (
    echo   No versions found in %USER_HOME%\.nimv
)
cd /d "%INITIAL_DIR%"
exit /b 0

:available
echo Getting list of available Nim versions...
for /f "tokens=2 delims=/." %%i in ('git ls-remote --tags https://github.com/nim-lang/Nim "v*"') do (
    set "version=%%i"
    if not "!version:~-2!"=="{}" (
        echo !version:~1!
    )
)
cd /d "%INITIAL_DIR%"
exit /b 0

:create_symlinks
set "bin_dir=%~1"
set "nimble_dir=%USER_HOME%\.nimble\bin"

if not exist "%nimble_dir%" mkdir "%nimble_dir%"

:: Create symbolic links for each binary
for %%b in (nim.exe nim-gdb.exe nimble.exe nimgrep.exe nimpretty.exe nimsuggest.exe testament.exe) do (
    if exist "%nimble_dir%\%%b" del "%nimble_dir%\%%b"
    if exist "%bin_dir%\%%b" mklink "%nimble_dir%\%%b" "%bin_dir%\%%b"
)
exit /b 0

:install_version
:: Set up paths
set "NIMV_DIR=%USER_HOME%\.nimv\%VERSION_NUM%"
set "NIM_DIR=%NIMV_DIR%\Nim"
set "NIM_BIN_PATH=%NIM_DIR%\bin"

:: Check if already installed
if exist "%NIM_BIN_PATH%\nim.exe" (
    echo Nim version %VERSION_NUM% is already installed at %NIM_BIN_PATH%
    echo Setting version %VERSION_NUM% as current version...
    call :create_symlinks "%NIM_BIN_PATH%"
    echo Done.
    cd /d "%INITIAL_DIR%"
    exit /b 0
)

:: Install new version
echo Installing Nim version %VERSION_NUM%...

if not exist "%NIMV_DIR%" mkdir "%NIMV_DIR%"
cd /d "%NIMV_DIR%"

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
    for /f "tokens=*" %%i in ('git tag ^| findstr /r "^v" ^| sort') do (
        set "version=%%i"
        echo !version:~1!
    )
    cd /d "%INITIAL_DIR%"
    rmdir /s /q "%NIMV_DIR%"
    exit /b 1
)

git checkout %VERSION_TAG%
call build_all.bat

if exist "%NIM_BIN_PATH%\nim.exe" (
    echo Setting version %VERSION_NUM% as current version...
    call :create_symlinks "%NIM_BIN_PATH%"
    echo Done.
) else (
    echo Error: Nim binary not found at %NIM_BIN_PATH%
    cd /d "%INITIAL_DIR%"
    exit /b 1
)

cd /d "%INITIAL_DIR%"
exit /b 0