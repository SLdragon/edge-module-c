@echo off
SETLOCAL EnableDelayedExpansion

set LOCAL_BIN_STAGING_DIR=BinariesToCopy
set VS_REMOTE_DEBUGGER_BIN="%VSINSTALLDIR%CoreCon\Binaries\Phone Tools\Debugger\target\x64"
set VS_REMOTE_DEBUGGER_LIB="%VSINSTALLDIR%CoreCon\Binaries\Phone Tools\Debugger\target\lib"
set VS_CRT_REDIST_REL[0]="%VcToolsRedistDir%onecore\x64\Microsoft.VC141.CRT"
set VS_CRT_REDIST_REL[1]="%VcToolsRedistDir%onecore\x64\Microsoft.VC150.CRT"
set VS_CRT_REDIST_DBG[0]="%VcToolsRedistDir%onecore\debug_nonredist\x64\Microsoft.VC141.DebugCRT"
set VS_CRT_REDIST_DBG[1]="%VcToolsRedistDir%onecore\debug_nonredist\x64\Microsoft.VC150.DebugCRT"

set UCRT_DLL_PATH="%WindowsSdkVerBinPath%\x64\ucrt"


set DockerImageName=vcmodule

:: Check execution environment
if "%VSINSTALLDIR%" == "" (
    goto RunFromDevCmd
)

::Check for VS 2017 + Pre-reqs
if not exist %VS_REMOTE_DEBUGGER_BIN% (
    goto NoVs
) 

::Check for docker
call docker.exe version >nul
if ERRORLEVEL 1 (
    goto NoDocker
)

:: Copy to local staging directory
echo Staging Remote Binaries.
call robocopy.exe %VS_REMOTE_DEBUGGER_BIN% %LOCAL_BIN_STAGING_DIR% /S /E >nul
if %ERRORLEVEL% GTR 8 (
    echo Error while staging debugger binaries. Exiting...
    exit /b 1
)

call robocopy.exe %VS_REMOTE_DEBUGGER_LIB% %LOCAL_BIN_STAGING_DIR% /S /E >nul
if %ERRORLEVEL% GTR 8 (
    echo Error while staging debugger binaries. Exiting...
    exit /b 1
)

for /L %%n in (0,1,1) do (
    call robocopy.exe !VS_CRT_REDIST_DBG[%%n]! %LOCAL_BIN_STAGING_DIR% /S /E >nul
    if !ERRORLEVEL! LEQ 8 (
        goto StageResistDbgOk
    )
)
echo Error while staging debugger binaries. Exiting...
exit /b 1
:StageResistDbgOk

for /L %%n in (0,1,1) do (
    call robocopy.exe !VS_CRT_REDIST_REL[%%n]! %LOCAL_BIN_STAGING_DIR% /S /E >nul
    if !ERRORLEVEL! LEQ 8 (
        goto StageResistRelOk
    )
)
echo Error while staging debugger binaries. Exiting...
exit /b 1
:StageResistRelOk

call robocopy.exe %UCRT_DLL_PATH% %LOCAL_BIN_STAGING_DIR% /S /E >nul
if %ERRORLEVEL% GTR 8 (
    :: Non-fatal error, but debug binaries won't work
    echo Warning! Unable to stage UCRT dll, debug binaries will not run in the container.
)


echo Building container...
set dockerBuildCmd=docker build -f Dockerfile -t %DockerImageName% x64/Debug

call %dockerBuildCmd% > nul

if exist %LOCAL_BIN_STAGING_DIR% (
    rd /Q /S %LOCAL_BIN_STAGING_DIR%
)

:: start module
iotedgehubdev start -d ".\deployment.amd64.json"
