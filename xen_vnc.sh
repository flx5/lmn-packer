#!/bin/bash

function usage () {
    echo "Usage:"
    echo "   `basename $0` -h <xenserver host> -g <guest vm name-label>"
    echo "   `basename $0` -h <xenserver host> -u <guest vm uuid>"
    echo "   `basename $0` -h <xenserver host> -d <domID>"
    exit 1
}

port=22

while getopts "h:g:u:d:p:" option
do
    case $option in
        h ) xs=${OPTARG} ;;
        g ) vm=${OPTARG} ;;
        u ) uu=${OPTARG} ;;
        d ) id=${OPTARG} ;;
        p ) port=${OPTARG} ;;
        * ) usage
    esac
done

if [ -z ${xs} ]; then
    usage
fi

if [ -z ${uu} ] && [ -z ${vm} ] && [ -z ${id} ]; then
    usage
fi

if [ ! -z ${uu} ]; then
    domid=`ssh -p ${port} root@${xs} xe vm-list uuid=${uu} params=dom-id --minimal`
elif [ ! -z ${vm} ]; then
    domid=`ssh -p ${port} root@${xs} xe vm-list name-label=${vm} params=dom-id --minimal`
elif [ ! -z ${id} ]; then
    domid=${id}
fi

if [ -z ${domid} ]; then
    echo "Could not find guest ${vm}${uu} on host ${xs}."
    exit 1
elif [ ${domid} -lt 0 ]; then
    echo "Guest ${vm}${uu} has no dom-id. Is your vm running?"
    exit 1
fi

ssh -p ${port} -L 5900:127.0.0.1:5911 root@${xs} socat -d TCP4-LISTEN:5911 UNIX-CONNECT:/var/run/xen/vnc-${domid}
SSH_PID=$!

echo "Connect to vnc://localhost:5911"

wait $SSH_PID

exit 0
port=`ssh -p ${port} root@${xs} xenstore-read /local/domain/${domid}/console/vnc-port`

if [ -z ${port} ]; then
    echo "Couldn't read VNC port from xenstore. Is your vm running?"
    exit 1
fi

echo "Connecting to vnc port ${port} on host ${xs}..."
set -x
vncviewer -via root@${xs} localhost::${port}*/
