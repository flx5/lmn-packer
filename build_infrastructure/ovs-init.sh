#!/bin/bash
#
# Init file for OpenFlow configuration
#
# chkconfig: 2345 21 78
# description: OpenFlow bridge configuration
#

# source function library
. /etc/rc.d/init.d/functions

VSCTL=/usr/bin/ovs-vsctl

controller_ip=192.168.0.200

start() {
  ovs-vsctl add-br br1
  ip addr add 10.0.0.70/8 dev br1
  ip link set br1 up
}

stop() {
        echo -n $"Action not supported"
        failure $"Action not supported"
        echo
        return 1;
}

restart() {
        echo -n $"Action not supported"
        failure $"Action not supported"
        echo
        return 1;
}

case "$1" in
  start)
        start
        ;;
  stop)
        stop
        ;;
  restart)
        restart
        ;;
  *)
        echo $"Usage: $0 {start|stop|restart}"
        exit 1
esac

