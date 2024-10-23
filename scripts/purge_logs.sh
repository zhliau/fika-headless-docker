#!/bin/bash  -e

client_dir=/opt/tarkov
logs_dir=$client_dir/Logs
bepinex_logs_dir=$client_dir/BepInEx/
bepinex_logs_pattern=LogOutput-*.log

if [[ -d $logs_dir ]]; then
    echo "Purging logs dir $logs_dir" >> /proc/1/fd/1
    reclaimed_space=$(du -hs $logs_dir | awk '{print $1}')
    rm -r $logs_dir/*
    echo "Successfully cleared $reclaimed_space of logs" >> /proc/1/fd/1
fi
if [[ -d $bepinex_logs_dir ]]; then
    echo "Purging BepInEx logs in $logs_dir" >> /proc/1/fd/1
    reclaimed_space=$(du -hsc $bepinex_logs_dir/$bepinex_logs_pattern 2>&1 | tail -1 | awk '{print $1}')

    # Only remove LogOutput files with timestamps
    find $bepinex_logs_dir -name $bepinex_logs_pattern -exec rm {} \;
    echo "Successfully cleared $reclaimed_space of BepInEx logs" >> /proc/1/fd/1
fi
