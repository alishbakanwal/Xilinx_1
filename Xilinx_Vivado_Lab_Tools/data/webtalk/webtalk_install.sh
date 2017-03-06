#!/bin/sh

WEBTALK_SETTINGS=`dirname $0`/webtalksettings

if [ $# != 1 ]; then
    echo "Specify on or off"
elif [ "$1" == "on" ]; then 
    # Rodin Webtalk setup
    rm -f $WEBTALK_SETTINGS
    echo "collectusagestatistics=true" > $WEBTALK_SETTINGS

elif [ "$1" == "off" ]; then
    # Rodin Webtalk setup
    rm -f $WEBTALK_SETTINGS
    echo "collectusagestatistics=false" > $WEBTALK_SETTINGS

else
    echo "Valid options are on and off"
fi
