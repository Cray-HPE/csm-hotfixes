#!/usr/bin/env bash

# Copyright 2021 Hewlett Packard Enterprise Development LP

set -o errexit
set -o pipefail
set -o xtrace

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")"
source "${ROOTDIR}/lib/version.sh"

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
yq w -i "${workdir}/sysmgmt.yaml" 'spec.charts.(name==cray-hms-hmnfd).version' 1.7.5

# Update the product catalog to report CSM 0.9.5
yq w -i "${workdir}/sysmgmt.yaml" 'spec.charts.(name==csm-config).values.cray-import-config.import_job.CF_IMPORT_PRODUCT_VERSION' "$RELEASE_VERSION"
yq w -i "${workdir}/sysmgmt.yaml" 'spec.charts.(name==csm-config).values.cray-import-config.catalog.image.tag' 0.0.9
yq w -i "${workdir}/sysmgmt.yaml" 'spec.charts.(name==cray-csm-barebones-recipe-install).values.cray-import-kiwi-recipe-image.import_job.PRODUCT_VERSION' "$RELEASE_VERSION"
yq w -i "${workdir}/sysmgmt.yaml" 'spec.charts.(name==cray-csm-barebones-recipe-install).values.cray-import-kiwi-recipe-image.import_job.name' "csm-image-recipe-import-${RELEASE_VERSION}"
yq w -i "${workdir}/sysmgmt.yaml" 'spec.charts.(name==cray-csm-barebones-recipe-install).values.cray-import-kiwi-recipe-image.catalog.image.tag' 0.0.9

# Distribute and run script to patch kube-system manifests
masters=$(kubectl get node --selector='node-role.kubernetes.io/master' -o name | sed -e 's,^node/,,' | paste -sd,)
export PDSH_SSH_ARGS_APPEND="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
export IFS=","
for master in $masters; do
  ssh-keyscan -H "$master" 2> /dev/null >> ~/.ssh/known_hosts
  scp ${ROOTDIR}/patch-manifests.sh $master:/tmp
  pdsh -w $master "/tmp/patch-manifests.sh"
  # Give K8S a chance to spin up pods for this node
  sleep 10
done
unset IFS

# Distribute and configure node-exporter to storage nodes
num_storage_nodes=$(craysys metadata get num-storage-nodes)
for node_num in $(seq $num_storage_nodes); do
  ssh-keyscan -H "$storage_node" 2> /dev/null >> ~/.ssh/known_hosts
  storage_node=$(printf "ncn-s%03d" "$node_num")
  scp ${ROOTDIR}/files/node_exporter $storage_node:/usr/bin
  scp ${ROOTDIR}/install-node_exporter-storage.sh $storage_node:/tmp
  pdsh -w $storage_node "/tmp/install-node_exporter-storage.sh"
done

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
