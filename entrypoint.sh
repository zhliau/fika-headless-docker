#!/bin/bash -e

eft_dir=/opt/tarkov
eft_binary=$eft_dir/EscapeFromTarkov.exe
bepinex_logfile=$eft_dir/BepInEx/LogOutput.log
wine_logfile_name=wine.log
wine_logfile=$eft_dir/$wine_logfile_name

xvfb_run=""
nographics="-nographics"
batchmode="-batchmode"
nodynamicai="-noDynamicAI"

xlockfile=/tmp/.X0-lock
# Overriden if you use DGPU
export DISPLAY=:0.0

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

if [ "$AUTO_RESTART_ON_RAID_END" == "true" ]; then
    echo "Running Xvfb in background for raid end autorestart"
    xvfb_run=""
fi

if [ "$XVFB_DEBUG" == "true" ]; then
    echo "Xvfb debug is ON. This will start xvfb in the foreground. Not supported if DGPU is enabled."
    xvfb_run="xvfb-run -a -e /dev/stdout"
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
    # I'm not sure why, but each time the client exits
    # we have to restart xvfb otherwise it'll fail to create a batchmode window
    if pgrep -x "Xvfb" > /dev/null; then
        echo "Cleaning up old xvfb processes"
        pkill Xvfb
    fi
    if [ -f "$xlockfile" ]; then rm -f $xlockfile; fi
    echo "Starting Xvfb in background"
    /usr/bin/Xvfb :0 -screen 0 1024x768x16 2>&1 &
    xvfb_pid=$!
    echo "Xvfb running PID is $xvfb_pid"
}

start_crond() {
    echo "Starting crond"
    /etc/init.d/cron reload
    /etc/init.d/cron start
}

# Main client function. Should block until client has exited
# Since we now run EFT client in background, end function
# via watching for raid end (if autorestart is enabled)
# or via watching the PID
run_client() {
    echo "Using wine executable $WINE_BIN_PATH/wine"
    WINEDEBUG=-all $xvfb_run $WINE_BIN_PATH/wine $eft_binary $batchmode $nographics $nodynamicai -token="$PROFILE_ID" -config="{'BackendUrl':'http://$SERVER_URL:$SERVER_PORT', 'Version':'live'}" &> $wine_logfile &

    eft_pid=$!
    echo "EFT PID is $eft_pid"

    # Show BepInEx logs in docker logs.
    tail -f $bepinex_logfile &

    # Blocking function
    # TODO to make this more extensible, can these be turned into functions and have this function wait for them to complete?
    if [[ "$AUTO_RESTART_ON_RAID_END" == "true" ]]; then
        echo "Starting BepInEx/LogOutput.log watch for auto-restart on raid end"
        grep -q "Destroyed FikaServer" <(tail -F -n 0 $bepinex_logfile) \
            && echo "Raid ended, restarting dedicated client" \
            && sleep 10 \
            && kill -9 $eft_pid
    else
        echo "Waiting for EFT to exit"
        tail --pid=$eft_pid -f /dev/null
    fi
}

echo "Running wineboot update. Please wait ~60s. See $wine_logfile_name for logs."
$WINE_BIN_PATH/wineboot --update &> $wine_logfile

if [[ "$ENABLE_LOG_PURGE" == "true" ]]; then
    echo "Enabling log purge"
    cp /opt/cron/cron_purge_logs /etc/cron.d/
    start_crond
fi

run_xvfb
if [[ "$USE_MODSYNC" == "true" || "$AUTO_RESTART_ON_RAID_END" == "true" ]]; then
    while true; do
        # Anticipate the client exiting due to modsync or raid end, and restart it
        run_client
        echo "Dedi client closed with exit code $?. Restarting.." >&2
        sleep 5
    done
else
    run_client
fi
