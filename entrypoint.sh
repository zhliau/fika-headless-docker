#!/bin/bash

EFT_BINARY=/opt/tarkov/EscapeFromTarkov.exe
LIVE_DIR=/opt/live/
PREFIX=/home/fika/.wine
PREFIX_LIVE_DIR=$PREFIX/drive_c/live

# Probably not needed with xvfb-run
# nohup /usr/bin/Xvfb ":0" -screen 0 1024x768x16 >/dev/null 2>&1 &
# export DISPLAY=:0

# If directory doesn't exist or is empty
if [ ! -d $PREFIX_LIVE_DIR ] || [ -z "$(ls -A $PREFIX_LIVE_DIR)" ]; then
    echo "Symlinking live dir"
    ln -s /opt/live $PREFIX_LIVE_DIR
# TODO make this more robust
elif [ ! -f $PREFIX_LIVE_DIR/ConsistencyInfo ]; then
    echo "Live files not found! Make sure you mount a folder containing the live files to /opt/live"
    exit 1
fi

# Start dedicated client
if [ ! -f $EFT_BINARY ]; then
    echo "EFT Binary $EFT_BINARY not found! Please make sure you have mounted the Fika client directory to /opt/tarkov"
    exit 1
else
    WINEDEBUG=-all xvfb-run -a wine /opt/tarkov/EscapeFromTarkov.exe -batchmode -token="$PROFILE_ID" -config="{'BackendUrl':'http://$SERVER_URL:$SERVER_PORT', 'Version':'live'}" 
fi
