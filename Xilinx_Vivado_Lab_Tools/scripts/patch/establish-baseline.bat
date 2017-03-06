@echo off

if [%1] == [] (
    set /p BASELINE=Please provide the absolute path of the full install being patched: 
) else (
    set BASELINE=%~f1
)

if [%BASELINE%] == [] (
    echo ERROR: A baseline must be provided
    exit /b 1
)

rem # Strip whitespace
set BASELINE=%BASELINE: =%

set DATADIR=%~dps0..\..\data

if not exist "%BASELINE%" (
    echo ERROR: "%BASELINE%" does not exist
    exit /b 1
)

if not exist "%BASELINE%\bin" (
    echo ERROR: "%BASELINE%\bin" does not exist
    exit /b 1
)

if not exist "%BASELINE%\bin\*" (
    echo ERROR: "%BASELINE%\bin is not a directory"
    exit /b 1
)

del /F %DATADIR%\baseline.txt > NUL 2>&1
echo %BASELINE%> %DATADIR%\baseline.txt
