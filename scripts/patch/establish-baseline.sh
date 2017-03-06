#!/bin/sh

if [ $# -lt 1 ]; then
    read -p "Please enter the absolute path of the full install being patched: "  BASELINE
else
    BASELINE=$(readlink -f $1)
fi

if [ -z "$BASELINE" ]; then
    echo "ERROR: A baseline must be provided"
    exit 1
fi

DATADIR="$(dirname $0)/../../data"

if [ ! -d $BASELINE ]; then
    echo "ERROR: \"$BASELINE\" does not exist"
    exit 1
fi

if [ ! -d $BASELINE/bin ]; then
    echo "ERROR: \"$BASELINE/bin\" does not exist"
    exit 1
fi

rm -f $DATADIR/baseline.txt
echo $BASELINE > $DATADIR/baseline.txt

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
