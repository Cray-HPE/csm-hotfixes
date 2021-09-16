#!/usr/bin/env bash

# Copyright 2021 Hewlett Packard Enterprise Development LP

set -o errexit
set -o pipefail
set -o xtrace

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")"
source "${ROOTDIR}/lib/version.sh"
source "${ROOTDIR}/scripts/update-bss-metadata.sh"

# Create scratch space
workdir="$(mktemp -d)"
trap "rm -fr '${workdir}'" EXIT

# Patch platform manifest
kubectl -n loftsman get cm loftsman-platform -o jsonpath='{.data.manifest\.yaml}' > "${workdir}/platform.yaml"
# Update cray-sysmgmt-health
yq w -i "${workdir}/platform.yaml" 'spec.charts.(name==cray-sysmgmt-health).version' 0.12.6

# Patch sysmgmt manifest
kubectl -n loftsman get cm loftsman-sysmgmt -o jsonpath='{.data.manifest\.yaml}' > "${workdir}/sysmgmt.yaml"
# Update cray-hms-hmnfd
yq w -i "${workdir}/sysmgmt.yaml" 'spec.charts.(name==cray-hms-hmnfd).version' 1.8.7

# Update the product catalog to report CSM 0.9.11
yq w -i "${workdir}/sysmgmt.yaml" 'spec.charts.(name==csm-config).values.cray-import-config.import_job.CF_IMPORT_PRODUCT_VERSION' "$RELEASE_VERSION"
yq w -i "${workdir}/sysmgmt.yaml" 'spec.charts.(name==csm-config).values.cray-import-config.catalog.image.tag' 0.0.9
yq w -i "${workdir}/sysmgmt.yaml" 'spec.charts.(name==cray-csm-barebones-recipe-install).values.cray-import-kiwi-recipe-image.import_job.PRODUCT_VERSION' "$RELEASE_VERSION"
yq w -i "${workdir}/sysmgmt.yaml" 'spec.charts.(name==cray-csm-barebones-recipe-install).values.cray-import-kiwi-recipe-image.import_job.name' "csm-image-recipe-import-${RELEASE_VERSION}"
yq w -i "${workdir}/sysmgmt.yaml" 'spec.charts.(name==cray-csm-barebones-recipe-install).values.cray-import-kiwi-recipe-image.catalog.image.tag' 0.0.9

# Load artifacts into nexus
${ROOTDIR}/lib/setup-nexus.sh

# Distribute and run script to patch kube-system manifests
masters=$(kubectl get node --selector='node-role.kubernetes.io/master' -o name | sed -e 's,^node/,,' | paste -sd,)
export PDSH_SSH_ARGS_APPEND="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
export IFS=","
for master in $masters; do
  ssh-keyscan -H "$master" 2> /dev/null >> ~/.ssh/known_hosts
  scp ${ROOTDIR}/scripts/patch-manifests.sh $master:/tmp
  pdsh -w $master "/tmp/patch-manifests.sh"
  # Give K8S a chance to spin up pods for this node
  sleep 10
done
unset IFS

# Ensuring cloud-init is healthy
set +e
cloud-init query -a > /dev/null 2>&1
rc=$?
if [[ "$rc" -ne 0 ]]; then
  # Attempt to repair cached data
  cloud-init init > /dev/null 2>&1
fi
set -o errexit

# Distribute and configure node-exporter to storage nodes
num_storage_nodes=$(craysys metadata get num-storage-nodes)
for node_num in $(seq $num_storage_nodes); do
  storage_node=$(printf "ncn-s%03d" "$node_num")
  ssh-keyscan -H "$storage_node" 2> /dev/null >> ~/.ssh/known_hosts
  status=$(pdsh -N -w $storage_node "systemctl is-active node_exporter")
  if [ "$status" == "active" ]; then
    pdsh -w $storage_node "systemctl stop node_exporter; zypper rm -y golang-github-prometheus-node_exporter"
  fi
  pdsh -w $storage_node "zypper --no-gpg-checks in -y https://packages.local/repository/casmrel-755/cray-node-exporter-1.2.2.1-1.x86_64.rpm"
done

#
#  Updating bss metadata runcmd in order to make hotfix
#  survive node reuilds:
#
export TOKEN=$(curl -s -k -S -d grant_type=client_credentials -d client_id=admin-client -d client_secret=`kubectl get secrets admin-client-auth -o jsonpath='{.data.client-secret}' | base64 -d` https://api-gw-service-nmn.local/keycloak/realms/shasta/protocol/openid-connect/token | jq -r '.access_token')

update_bss_masters
update_bss_storage

function deploy() {
    while [[ $# -gt 0 ]]; do
        loftsman ship --charts-repo https://packages.local/repository/charts --manifest-path "$1"
        shift
    done
}

# Redeploy platform
deploy "${workdir}/platform.yaml"

# Redeploy sysmgmt
deploy "${workdir}/sysmgmt.yaml"


set +x
cat >&2 <<EOF
+ CSM applications and services upgraded
${0##*/}: OK
EOF
