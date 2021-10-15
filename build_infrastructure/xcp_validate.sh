#!/bin/bash

set -e

RED_NETWORK=$(xe network-list name-label='RED Internet' --minimal)
GREEN_NETWORK=$(xe network-list name-label='Green - LAN' --minimal)

if [[ -z "$RED_NETWORK" || -z "$GREEN_NETWORK" ]]; then
  echo "Network misconfigured"
  xe network-list
  exit 1
fi

GREEN_IP=$(ifconfig xenbr1 | awk '/inet / {print $2}')

if [[ "$GREEN_IP" != "10.0.0.70" ]]; then
  echo "green network misconfigured"
  ifconfig xenbr1
fi

LOCAL_STORAGE=$(xe sr-list  name-label="Local storage" --minimal)
LOCAL_COUNT=$(echo "$LOCAL_STORAGE" | wc -l)

if [[ -z "$LOCAL_STORAGE" || $LOCAL_COUNT -ne "1" ]]; then
  echo "storage misconfigured"
  xe sr-list
  exit 1
fi
