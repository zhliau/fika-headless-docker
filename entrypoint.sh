#!/bin/bash -e

eft_binary=/opt/tarkov/EscapeFromTarkov.exe
xvfb_run="xvfb-run -a"
nographics="-nographics"
batchmode="-batchmode"
nodynamicai="-noDynamicAI"

xlockfile=/tmp/.X0-lock
# Overriden if you use DGPU
export DISPLAY=:0.0

if [ "$XVFB_DEBUG" == "true" ]; then
    echo "Xvfb debug is ON. This is only supported for Xvfb running in foreground"
    xvfb_run="$xvfb_run -e /dev/stdout"
fi

if [ "$USE_GRAPHICS" == "true" ]; then
    echo "Using graphics"
    nographics=""
fi

if [ "$DISABLE_BATCHMODE" == "true" ]; then
    echo "Disabling batchmode"
    batchmode=""
fi

if [ "$DISABLE_NODYNAMICAI" == "true" ]; then
    echo "Allowing dynamic AI"
    nodynamicai=""
fi

if [ "$USE_MODSYNC" == "true" ]; then
    echo "Running Xvfb in background for modsync"
    xvfb_run=""
fi

if [ "$USE_DGPU" == "true" ]; then
    source /opt/scripts/install_nvidia_deps.sh

    DISPLAY=:0
    # Run Xorg server with required extensions
    sudo /usr/bin/Xorg "${DISPLAY}" vt7 -noreset -novtswitch -sharevts -dpi "${DISPLAY_DPI}" +extension "COMPOSITE" +extension "DAMAGE" +extension "GLX" +extension "RANDR" +extension "RENDER" +extension "MIT-SHM" +extension "XFIXES" +extension "XTEST" &

    # Wait for X server to start
    echo 'Waiting for X Socket' && until [ -S "/tmp/.X11-unix/X${DISPLAY#*:}" ]; do sleep 0.5; done && echo 'X Server is ready'
    unset xvfb_run
fi

if [ ! -f $eft_binary ]; then
    echo "EFT Binary $eft_binary not found! Please make sure you have mounted the Fika client directory to /opt/tarkov"
    exit 1
fi

run_xvfb() {
    /usr/bin/Xvfb :0 -screen 0 1024x768x16 2>&1 &
}

run_client() {
    echo "Using wine executable $WINE"
    if ! pgrep Xvfb; then
        echo "Xvfb process not found. Restarting Xvfb."
        run_xvfb
    fi
    WINEDEBUG=-all $xvfb_run $WINE $eft_binary $batchmode $nographics $nodynamicai -token="$PROFILE_ID" -config="{'BackendUrl':'http://$SERVER_URL:$SERVER_PORT', 'Version':'live'}"
}

start_crond() {
    echo "Starting crond"
    /etc/init.d/cron reload
    /etc/init.d/cron start
}

if [[ "$ENABLE_LOG_PURGE" == "true" ]]; then
    echo "Enabling log purge"
    cp /opt/cron/cron_purge_logs /etc/cron.d/
    start_crond
fi

if [ "$USE_MODSYNC" == "true" ]; then
    while true; do
        # Anticipate the client exiting due to modsync, and restart it after modsync external updater has done its thing
        # I don't know why, but it seems on second run of the client it always fails to create a batchmode window,
        # so we have to restart xvfb after each run
        if pgrep -x "Xvfb" > /dev/null; then
            echo "Cleaning up old xvfb processes"
            pkill Xvfb
        fi
        if [ -f "$xlockfile" ]; then rm -f $xlockfile; fi

        echo "Starting Xvfb in background"
        run_xvfb
        xvfb_pid=$!

        echo "Starting client. Xvfb running PID is $xvfb_pid"
        run_client
        echo "Dedi client closed with exit code $?. Restarting.." >&2
        kill -9 $xvfb_pid
        sleep 5
    done
else
    # run_xvfb
    run_client
fi
