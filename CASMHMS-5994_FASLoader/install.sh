#!/usr/bin/env bash
set -e
set -x

currentFASVersion=$(cray fas service version list --format json | jq -r .[])

if [ "$currentFASVersion" != "1.24.0" ]; then
  echo "This patch updates FAS from 1.24.0 to 1.24.1"
  echo "Current FAS Version $currentFASVersion"
  exit
fi

if [ -f "fas-1.24.1.tar" ]; then
  podman load -i fas-1.24.1.tar
else
  podman pull us-docker.pkg.dev/csm-release/csm-docker/stable/cray-firmware-action:1.24.1
fi

https_proxy=

NEXUS_PASSWORD="$(kubectl -n nexus get secret nexus-admin-credential --template {{.data.password}} | base64 -d)"
NEXUS_USERNAME="$(kubectl -n nexus get secret nexus-admin-credential --template {{.data.username}} | base64 -d)"

podman push \
    us-docker.pkg.dev/csm-release/csm-docker/stable/cray-firmware-action:1.24.1 \
    docker://registry.local/artifactory.algol60.net/csm-docker/stable/cray-firmware-action:1.24.1 \
    --creds "${NEXUS_USERNAME}:${NEXUS_PASSWORD}"``

kubectl -n services get deploy cray-fas -o yaml > fas.yaml
sed -i "s/cray-firmware-action:1.24.0/cray-firmware-action:1.24.1/g" fas.yaml
kubectl replace -f fas.yaml

echo "FAS v1.24.1 deployed"
echo "Wait for new FAS pod to start running:"
echo "   kubectl -n services get pods | grep fas"
echo "Check version of FAS (should be 1.24.1)"
echo "   cray fas service version list"
