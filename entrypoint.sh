#!/bin/bash -e

set_paths() {
    if [[ "$USE_PELICAN" == "true" ]]; then
        eft_dir=/home/container/tarkov
    else
        eft_dir=/opt/tarkov
    fi
    eft_binary=$eft_dir/EscapeFromTarkov.exe
    bepinex_logfile=$eft_dir/BepInEx/LogOutput.log
    wine_logfile_name=wine.log
    wine_logfile=$eft_dir/$wine_logfile_name
}

# Set default values
set_paths
xvfb_run="xvfb-run -a"
nographics="-nographics"
batchmode="-batchmode"
nodynamicai="-noDynamicAI"

save_log_on_exit=${SAVE_LOG_ON_EXIT:-false}
esync=${ESYNC:-false}
fsync=${FSYNC:-false}
ntsync=${NTSYNC:-false}
pelican=${PELICAN:-false}
port=${PORT:-6969} # Pelican overwrites the environment variable SERVER_PORT so we need to make another one available)
https=${HTTPS:-true}
proto=https

xlockfile=/tmp/.X0-lock
# Overriden if you use DGPU
export DISPLAY=:0.0

if [[ "$https" != "true" ]]; then
    proto=http
fi

if [[ "$esync" == "true" ]]; then
    echo "Enabling wine esync"
    export WINEESYNC=1
fi

if [[ "$ntsync" == "true" ]]; then
    echo "Using ntsync wine. Make sure your host has a kernel that supports ntsync."
    WINE_BIN_PATH=$WINE_NTSYNC_BIN_PATH
elif [[ "$fsync" == "true" ]]; then
    # fsync takes precedence
    if [[ "$esync" == "true" ]]; then
        export WINEESYNC=0
    fi
    echo "Enabling wine fsync"
    export WINEFSYNC=1
fi

if [ "$USE_PELICAN" == "true" ]; then
    echo "Running in Pelican mode as user $(whoami)"
    pelican=true
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
    if [ "$pelican" == "true" ]; then
        echo "EFT Binary $eft_binary not found! Please make sure you have uploaded the Fika client directory to /tarkov"
    else 
        echo "EFT Binary $eft_binary not found! Please make sure you have mounted the Fika client directory to /opt/tarkov"
    fi
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
    /usr/bin/Xvfb :0 -screen 0 1024x768x24 -ac +extension GLX +render -noreset -nolisten tcp -nolisten unix 2>&1 &
    xvfb_pid=$!
    echo "Xvfb running PID is $xvfb_pid"
}

start_crond() {
    echo "Starting crond"
    /etc/init.d/cron reload
    /etc/init.d/cron start
}

# Accepts EFT client PID as first arg
raid_end_routine() {
    echo "Starting BepInEx/LogOutput.log watch for auto-restart on raid end"
    grep -q "Destroyed FikaServer" <(tail -F -n 0 $bepinex_logfile) \
        && echo "Raid ended, restarting dedicated client" \
        && sleep 10 \
        && kill -9 $1
}


use_pelican() {
    MODIFIED_STARTUP=$(echo ${STARTUP} | sed -e 's/{{/${/g' -e 's/}}/}/g')
    
    # Run the Server
    echo "Modified Startup: ${MODIFIED_STARTUP}"
    echo "Running Pelican with user $(whoami)"
    eval ${MODIFIED_STARTUP}
}

init_pelican_wineprefix() {
    echo "Creating wineprefix for pelican"
    export WINEPREFIX=/home/container/.wine
    cp -r -u /.wine /home/container
    chown -R $(whoami) /home/container/.wine
}

# Main client function. Should block until client has exited
# Since we now run EFT client in background, end function
# via watching for raid end (if autorestart is enabled)
# or via watching the PID
run_client() {
    # Important that pelican gets called quickly so the console can attach for logging.
    if [[ "$pelican" == "true" ]]; then
        use_pelican
        # Assign the value from 'port' (which includes the default logic) to SERVER_PORT because Pelican overwrites the environment variable SERVER_PORT at runtime.
        SERVER_PORT=${port}
    fi

    echo "Using wine executable $WINE_BIN_PATH/wine"
    echo "Connecting to server $proto://$SERVER_URL:$SERVER_PORT"
    WINEDEBUG=-all $xvfb_run $WINE_BIN_PATH/wine $eft_binary $batchmode $nographics $nodynamicai -token="$PROFILE_ID" -config="{'BackendUrl':'$proto://$SERVER_URL:$SERVER_PORT', 'Version':'live'}" &> $wine_logfile &

    eft_pid=$!
    echo "EFT PID is $eft_pid"

    # Show BepInEx logs in docker logs.
    tail -f -n 0 $bepinex_logfile &
    logwatch_pid=$!

    if [[ "$AUTO_RESTART_ON_RAID_END" == "true" ]]; then
        raid_end_routine $eft_pid &
    fi

    # Blocking function
    echo "Waiting for EFT to exit"
    tail --pid=$eft_pid -f /dev/null

    if [[ "$save_log_on_exit" == "true" ]]; then
        timestamp=$(date +%Y%m%dT%H%M)
        cp $bepinex_logfile $eft_dir/BepInEx/LogOutput-$timestamp.log
        echo "Saved log as LogOutput-$timestamp.log"
    fi

    # Cleanup
    kill -9 $logwatch_pid
}

if [[ "$pelican" == true ]]; then
    init_pelican_wineprefix
fi

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
