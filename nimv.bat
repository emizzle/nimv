@echo off
setlocal EnableDelayedExpansion

:: Script version and immediate command handling
set "VERSION=0.0.4"
if "%~1"=="--version" (
    echo %VERSION%
    exit /b 0
)

:: Store initial directory and user home
set "INITIAL_DIR=%CD%"
set "USER_HOME=%USERPROFILE%"

:: Set up colors and symbols based on environment
set "GREEN=[92m"
set "RED=[91"
set "YELLOW=[93m"
set "CYAN=[96m"
set "NC=[0m"
set "TICK=+"
set "CROSS=x"
set "WARN=!"

:: Command handling
if "%~1"=="" goto help
if "%~1"=="--help" goto help
if "%~1"=="installed" goto installed
if "%~1"=="available" goto available
if "%~1"=="current" goto current
if "%~1"=="check" goto check

:: Version number validation
set INPUT_VERSION=%~1

:: Function to validate the version string
for /f "tokens=1-3 delims=." %%a in ("%INPUT_VERSION%") do (
    set MAJOR=%%a
    set MINOR=%%b
    set BUILD=%%c
)

:: Check if all components are integers and present
if "%MAJOR%"=="" goto invalid_version
if "%MINOR%"=="" goto invalid_version
if "%BUILD%"=="" goto invalid_version

for %%i in ("%MAJOR%" "%MINOR%" "%BUILD%") do (
    set IS_NUMERIC=1
    for /f "delims=0123456789" %%j in (%%i) do set IS_NUMERIC=0
    if !IS_NUMERIC!==0 goto invalid_version
)
set "VERSION_NUM=%~1"
set "VERSION_TAG=v%~1"
goto install_version

:invalid_version
echo Error: Invalid command or version format '%~1'
echo Use --help for usage information
cd /d "%INITIAL_DIR%"
exit /b 1

:: Show status messages for check
:show_status
setlocal EnableDelayedExpansion
set "message=%~1"
set "status=%~2"
if "%status%"=="success" (
    echo %GREEN%%TICK%%NC% %CYAN%%message%%NC%
) else if "%status%"=="warning" (
    echo %YELLOW%%WARN%%NC% %CYAN%%message%%NC%
) else (
    echo %RED%%CROSS%%NC% %CYAN%%message%%NC%
)
endlocal
exit /b

:help
echo Usage: %~n0%~x0 ^<command^|version-tag^>
echo.
echo Commands:
echo   installed      List all installed Nim versions
echo   available      List all available Nim versions
echo   current        Show current Nim version
echo   check          Verify correct installation and versions
echo   --version      Show script version
echo   --help         Show this help message
echo.
echo Parameters:
echo   version-tag    The Nim version to install (e.g., 2.0.14, 2.2.0)
echo.
echo Examples:
echo   %~n0%~x0 2.0.14      Install Nim version 2.0.14
echo   %~n0%~x0 installed   List installed versions
cd /d "%INITIAL_DIR%"
exit /b 0

:create_symlinks
set "bin_dir=%~1"
set "nimble_dir=%USER_HOME%\.nimble\bin"

if not exist "%nimble_dir%" mkdir "%nimble_dir%"

:: Create symbolic links for each binary
for %%b in (nim.exe nim-gdb.exe nimble.exe nimgrep.exe nimpretty.exe nimsuggest.exe testament.exe atlas.exe) do (
    if exist "%nimble_dir%\%%b" del "%nimble_dir%\%%b"
    if exist "%bin_dir%\%%b" mklink "%nimble_dir%\%%b" "%bin_dir%\%%b"
)

:: Check if .nimble/bin is in PATH
set "NIMBLE_BIN_PATH=%USER_HOME%\.nimble\bin"

:: Detect environment
set "IS_MSYS2="
if defined MSYSTEM set "IS_MSYS2=1"

:: Convert Windows path to Unix-style for MSYS2 if needed
if defined IS_MSYS2 (
    set "NIMBLE_BIN_PATH=%USER_HOME:\=/%/.nimble/bin"
)

:: Check PATH
if defined IS_MSYS2 (
    echo ";%PATH%;" | grep -q "%NIMBLE_BIN_PATH%"
    if !ERRORLEVEL! neq 0 (
        set "PATH=%NIMBLE_BIN_PATH%:!PATH!"
        echo.
        echo Note: %NIMBLE_BIN_PATH% has been added to PATH for this session
        echo To add it permanently in MSYS2:
        echo   1. Edit your shell configuration file ^(e.g., ~/.bashrc or ~/.bash_profile^)
        echo   2. Add the line: export PATH=\"%NIMBLE_BIN_PATH%:\$PATH\"
        echo   3. Restart your terminal or run: source ~/.bashrc
    )
) else (
    echo ";%PATH%;" | findstr /I /C:"%NIMBLE_BIN_PATH%" >nul
    if errorlevel 1 (
        set "PATH=%NIMBLE_BIN_PATH%;%PATH%"
        echo.
        echo Note: %NIMBLE_BIN_PATH% has been added to PATH for this session
        echo To add it permanently in Windows Command Prompt:
        echo   1. Open System Properties ^(Windows + Pause/Break^)
        echo   2. Click "Advanced system settings"
        echo   3. Click "Environment Variables"
        echo   4. Under "User variables for %USERNAME%", find "Path"
        echo   5. Click "Edit" and add: %NIMBLE_BIN_PATH%
        echo   6. Click OK on all windows
        echo   7. Restart any open terminals
    )
)
exit /b 0

:available
echo Getting list of available Nim versions...

:: Try using PowerShell to fetch tags (most reliable)
powershell -Command "try { $response = Invoke-WebRequest -Uri 'https://api.github.com/repos/nim-lang/Nim/tags?per_page=100' -UseBasicParsing; $tags = $response.Content | ConvertFrom-Json; $tags | ForEach-Object { if($_.name -match '^v\d+\.\d+\.\d+$') { $_.name.Substring(1) } } | Sort-Object -Descending } catch { Write-Host 'Error fetching tags: $_' }" > "%TEMP%\nim_versions.txt" 2>nul

:: Check if we got results
set "has_results=false"
for /f "tokens=*" %%a in ('type "%TEMP%\nim_versions.txt" 2^>nul') do (
    set "has_results=true"
    echo %%a
)

:: If PowerShell failed, try using curl directly
if "%has_results%"=="false" (
    :: Try curl approach
    curl -s "https://api.github.com/repos/nim-lang/Nim/tags?per_page=100" > "%TEMP%\tags.json" 2>nul
    if exist "%TEMP%\tags.json" (
        for /f "tokens=2 delims=:," %%a in ('findstr "\"name\"" "%TEMP%\tags.json"') do (
            set "tag=%%a"
            set "tag=!tag:"=!"
            set "tag=!tag: =!"
            if "!tag:~0,1!"=="v" (
                if "!tag:~-1!"=="}" set "tag=!tag:~0,-1!"
                if "!tag:~-1!"=="]" set "tag=!tag:~0,-1!"
                if "!tag:~-1!"=="\"" set "tag=!tag:~0,-1!"
                echo !tag:~1!
            )
        )
    )
)

:: Clean up
del "%TEMP%\nim_versions.txt" >nul 2>&1
del "%TEMP%\tags.json" >nul 2>&1

cd /d "%INITIAL_DIR%"
exit /b 0

:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: FIXED CURRENT COMMAND - SIMPLER APPROACH
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:current
set "nim_exe=%USER_HOME%\.nimble\bin\nim.exe"

if defined MSYSTEM (
    :: MSYS2 environment - keep what works
    readlink "%USER_HOME:\=/%/.nimble/bin/nim" > "%TEMP%\nim_link.txt" 2>nul
    for /f "tokens=5 delims=/" %%v in ('type "%TEMP%\nim_link.txt" 2^>nul') do (
        echo %%v
        del "%TEMP%\nim_link.txt" >nul 2>&1
        cd /d "%INITIAL_DIR%"
        exit /b 0
    )
    del "%TEMP%\nim_link.txt" >nul 2>&1
) else (
    :: Windows CMD environment - use a check file approach
    if exist "%nim_exe%" (
        :: Create a marker file
        echo Test > "%TEMP%\nimv_check.txt"

        :: Loop through each installed version
        for /d %%d in ("%USER_HOME%\.nimv\*") do (
            set "version=%%~nxd"
            set "version_path=%USER_HOME%\.nimv\!version!\Nim\bin\nim.exe"

            if exist "!version_path!" (
                :: Compare file sizes of symlink target and version binary
                fc "%nim_exe%" "!version_path!" >nul 2>&1
                if !ERRORLEVEL! equ 0 (
                    echo !version!
                    cd /d "%INITIAL_DIR%"
                    exit /b 0
                )
            )
        )
    )
)

echo No version currently selected
cd /d "%INITIAL_DIR%"
exit /b 0

:installed
echo Installed Nim versions:

:: Get current version first
set "current_version="
set "nim_exe=%USER_HOME%\.nimble\bin\nim.exe"

if defined MSYSTEM (
    :: MSYS2 environment - keep what works
    readlink "%USER_HOME:\=/%/.nimble/bin/nim" > "%TEMP%\nim_link.txt" 2>nul
    for /f "tokens=5 delims=/" %%v in ('type "%TEMP%\nim_link.txt" 2^>nul') do (
        set "current_version=%%v"
    )
    del "%TEMP%\nim_link.txt" >nul 2>&1
) else (
    :: Windows CMD environment - just use the current command directly
    for /f "tokens=*" %%v in ('"%~f0" current 2^>nul') do (
        if not "%%v"=="No version currently selected" (
            set "current_version=%%v"
        )
    )
)

:: Now list all installed versions
for /d %%d in ("%USER_HOME%\.nimv\*") do (
    if exist "%%d\Nim\bin\nim.exe" (
        for /f "tokens=*" %%v in ("%%~nxd") do (
            if "%%v"=="%current_version%" (
                echo  * %%v (current^)
            ) else (
                echo    %%v
            )
        )
    )
)

cd /d "%INITIAL_DIR%"
exit /b 0

:check
set "has_error=false"

:: Check nim binary
for /f "tokens=*" %%i in ('bash -c "which nim 2>/dev/null"') do set "nim_path=%%i"
if "%nim_path%"=="" (
    call :show_status "Checking nim binary platform matches current platform" "failure"
    echo   Error: nim not found in PATH
    set "has_error=true"
) else (
    call :show_status "Checking nim binary platform matches current platform" "success"
    echo   Valid executable at: %nim_path%
)

:: Check nim version matches
for /f "tokens=*" %%v in ('bash -c "nim --version 2>/dev/null | head -n1 | sed 's/Nim Compiler Version \([0-9.]*\).*/\1/'"') do set "nim_version=%%v"
for /f "tokens=*" %%v in ('bash -c "nimv current 2>/dev/null"') do set "current_version=%%v"

if "%nim_version%"=="" (
    call :show_status "Checking nim binary version matches nim version selected with nimv" "failure"
    echo   Error: Could not determine Nim version
    set "has_error=true"
) else if not "%nim_version%"=="%current_version%" (
    call :show_status "Checking nim binary version matches nim version selected with nimv" "failure"
    echo   Currently selected version: %current_version%
    echo   Nim binary reports: %nim_version%
    set "has_error=true"
) else (
    call :show_status "Checking nim binary version matches nim version selected with nimv" "success"
    echo   Version matches: %nim_version%
)

:: Check nimv version
for /f "tokens=*" %%v in ('bash -c "git ls-remote --tags https://github.com/emizzle/nimv | grep -o '[0-9][0-9.]*$' | sort -V | tail -n1"') do set "latest_version=%%v"

if not defined latest_version (
    call :show_status "Checking if nimv has available updates" "failure"
    echo   Error: Could not determine latest version
    set "has_error=true"
) else (
    if "%VERSION%" GEQ "%latest_version%" (
        call :show_status "Checking if nimv has available updates" "success"
        echo   Currently up-to-date: %VERSION%
    ) else (
        call :show_status "Checking if nimv has available updates" "warning"
        echo   Current version: %VERSION%
        echo   Latest version: %latest_version%
        echo.
        echo To update, run:
        echo   choco upgrade nimv
    )
)

if "%has_error%"=="true" (
    exit /b 1
) else (
    exit /b 0
)

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
if %ERRORLEVEL% neq 0 (
    echo %RED%Error: Failed to build Nim version %VERSION_NUM%%NC%
    echo   Check the above output for errors.
    echo   Possible reasons:
    echo   - Missing build dependencies
    echo   - Incompatible build environment
    echo   - Compilation errors in Nim source
    cd /d "%INITIAL_DIR%"
    rmdir /s /q "%NIMV_DIR%"
    exit /b 1
)

if exist "%NIM_BIN_PATH%\nim.exe" (
    echo Setting version %VERSION_NUM% as current version...
    call :create_symlinks "%NIM_BIN_PATH%"

    echo Cleaning up installation directory...
    cd /d "%NIM_DIR%"
    set "exclude=|bin|lib|dist|config|compiler|"
    for /d %%i in (*) do if "!exclude:|%%~i|=!" equ "%exclude%" rd /s /q "%%~i"
    for /d %%i in (dist\*) do if not "%%i"=="dist\checksums" rd /s /q "%%i"
    for %%i in (*) do del /q "%%i"

    :: Remove nim_csources binary from bin
    for %%F in ("%NIM_BIN_PATH%\nim_csources*") do del /f /q "%%F" 2>nul

    echo Done.
) else (
    echo Error: Nim binary not found at %NIM_BIN_PATH%
    cd /d "%INITIAL_DIR%"
    exit /b 1
)

cd /d "%INITIAL_DIR%"
exit /b 0