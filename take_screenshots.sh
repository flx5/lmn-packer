#!/bin/bash

LOGFILE=$1
PREFIX=$2

mkdir -p screenshots

# While packer is running
while true; do
    VNC_URL=$(grep -o -E 'vnc\:\/\/([0-9\.:]+)' $LOGFILE)
    
    if [ -z "$VNC_URL" ]; then
       echo "vnc url not found..."
    else
       echo "Taking screenshot at $VNC_URL"
       # Remove vnc:// prefix
       VNC_URL=${VNC_URL#*vnc://}
       # Replace : with :: for snapshot
       VNC_URL=${VNC_URL//:/::}
       vncsnapshot "$VNC_URL" screenshots/${PREFIX}-screenshot-$(date +%Y%m%d-%H%M%S).jpg
    fi

    sleep 60
done
