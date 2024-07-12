#!/bin/bash -e

EFT_BINARY=/opt/tarkov/EscapeFromTarkov.exe
LIVE_DIR=/opt/live/
PREFIX=/home/ubuntu/.wine
PREFIX_LIVE_DIR=$PREFIX/drive_c/live
XVFB_RUN="xvfb-run -a"

if [ "$XVFB_DEBUG" == "true" ]; then
    XVFB_RUN="$XVFB_RUN -e /dev/stdout"
fi

# If directory doesn't exist or is empty
if [ ! -d $PREFIX_LIVE_DIR ] || [ -z "$(ls -A $PREFIX_LIVE_DIR)" ]; then
    echo "Symlinking live dir"
    ln -s /opt/live $PREFIX_LIVE_DIR
# TODO make this more robust
elif [ ! -f $PREFIX_LIVE_DIR/ConsistencyInfo ]; then
    echo "Live files not found! Make sure you mount a folder containing the live files to /opt/live"
    exit 1
fi

if [ "$USE_DGPU" == "true" ]; then
	source /opt/scripts/install_nvidia_deps.sh

	# Run Xorg server with required extensions
	sudo /usr/bin/Xorg "${DISPLAY}" vt7 -noreset -novtswitch -sharevts -dpi "${DISPLAY_DPI}" +extension "COMPOSITE" +extension "DAMAGE" +extension "GLX" +extension "RANDR" +extension "RENDER" +extension "MIT-SHM" +extension "XFIXES" +extension "XTEST" &

	# Wait for X server to start
	echo 'Waiting for X Socket' && until [ -S "/tmp/.X11-unix/X${DISPLAY#*:}" ]; do sleep 0.5; done && echo 'X Server is ready'
	unset XVFB_RUN
fi

if [ ! -f $EFT_BINARY ]; then
    echo "EFT Binary $EFT_BINARY not found! Please make sure you have mounted the Fika client directory to /opt/tarkov"
    exit 1
fi

# Start client
WINEDEBUG=-all $XVFB_RUN wine $EFT_BINARY -batchmode -token="$PROFILE_ID" -config="{'BackendUrl':'http://$SERVER_URL:$SERVER_PORT', 'Version':'live'}" 
