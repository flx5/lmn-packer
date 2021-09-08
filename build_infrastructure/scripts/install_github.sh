#!/bin/bash

set -e
export DEBIAN_FRONTEND=noninteractive 

adduser --system github

echo 'github ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/github

apt-get install -y jq

su github -s /bin/bash <<'EOF'
       cd /home/github
       
       RUNNERS=$(curl -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPOSITORY}/actions/runners/downloads)
       RUNNER_URL=$(jq --raw-output '.[] | select(.os == "linux" and .architecture == "x64").download_url' <<< $RUNNERS)
       
       curl -Ls "$RUNNER_URL" | tar xz
       sudo ./bin/installdependencies.sh
       
       registration_url="https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPOSITORY}/actions/runners/registration-token"
       echo "Requesting registration URL at '${registration_url}'"

       payload=$(curl -sX POST -H "Authorization: token ${GITHUB_PAT}" ${registration_url})
       RUNNER_TOKEN=$(echo $payload | jq .token --raw-output)
    
       ./config.sh --unattended --name $(hostname) --replace --url https://github.com/${GITHUB_OWNER}/${GITHUB_REPOSITORY} --token ${RUNNER_TOKEN}
       sudo ./svc.sh install github
EOF