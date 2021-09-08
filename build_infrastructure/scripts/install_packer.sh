#!/bin/bash

set -e

export DEBIAN_FRONTEND=noninteractive 

wget https://apt.releases.hashicorp.com/gpg -O- | gpg --dearmor > /usr/share/keyrings/hashicorp-archive-keyring.pgp

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/hashicorp-archive-keyring.pgp] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list

apt-get update

apt-get install -y packer
