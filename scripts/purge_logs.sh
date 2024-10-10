#!/bin/bash  -e

client_dir=/opt/tarkov
logs_dir=$client_dir/Logs

if [[ -d $logs_dir ]]; then
    echo "Purging logs dir $logs_dir" >> /proc/1/fd/1
    reclaimed_space=$(du -hs $logs_dir | awk '{print $1}')
    rm -r $logs_dir/*
    echo "Successfully cleared $reclaimed_space of logs" >> /proc/1/fd/1
fi
