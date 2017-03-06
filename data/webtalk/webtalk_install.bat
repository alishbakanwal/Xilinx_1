@echo off

set WEBTALK_SETTINGS="%~dp0webtalksettings"

if [%1] == [] (
    echo Specify on or off
) else (
if [%1] == [on] (
    del /F %WEBTALK_SETTINGS%>NUL
    echo collectusagestatistics=true > %WEBTALK_SETTINGS%
) else (
if [%1] == [off] (
    del /F %WEBTALK_SETTINGS%>NUL
    echo collectusagestatistics=false > %WEBTALK_SETTINGS%
) else (
    echo Valid options are on and off
)))
