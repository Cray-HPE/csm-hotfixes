#!/usr/bin/env bash

# Copyright 2021 Hewlett Packard Enterprise Development LP

set -o errexit
set -o pipefail
set -o xtrace

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")"
source "${ROOTDIR}/lib/version.sh"

# Install new CSI
rpm -Uvh --force ${ROOTDIR}/rpm/x86_64/cray-site-init-1.14.0-1.x86_64.rpm
csi handoff upload-utils --kubeconfig /etc/kubernetes/admin.conf

# Create scratch space
workdir="$(mktemp -d)"
trap "rm -fr '${workdir}'" EXIT

# Patch sysmgmt manifest
kubectl -n loftsman get cm loftsman-sysmgmt -o jsonpath='{.data.manifest\.yaml}' > "${workdir}/sysmgmt.yaml"
# Update csm-config
yq w -i "${workdir}/sysmgmt.yaml" 'spec.charts.(name==csm-config).version' 1.9.8
yq w -i "${workdir}/sysmgmt.yaml" 'spec.charts.(name==csm-config).values.cray-import-config.catalog.image.tag' 1.3.1
# Update bss
yq w -i "${workdir}/sysmgmt.yaml" 'spec.charts.(name==cray-hms-bss).version' 2.0.3
# Update cfs-operator
yq w -i "${workdir}/sysmgmt.yaml" 'spec.charts.(name==cray-cfs-operator).version' 1.14.9

yq w -i "${workdir}/sysmgmt.yaml"  'spec.sources.charts(name==csm).location' https://packages.local/repository/charts
yq w -i "${workdir}/sysmgmt.yaml"  'spec.sources.charts(name==csm).type' repo
yq w -i "${workdir}/sysmgmt.yaml"  'spec.sources.charts(name==csm-algol60).location' https://packages.local/repository/charts
yq w -i "${workdir}/sysmgmt.yaml"  'spec.sources.charts(name==csm-algol60).type' repo

# Load artifacts into nexus
${ROOTDIR}/lib/setup-nexus.sh

function deploy() {
    while [[ $# -gt 0 ]]; do
        loftsman ship --charts-repo https://packages.local/repository/charts --manifest-path "$1"
        shift
    done
}

# Redeploy platform
deploy "${workdir}/sysmgmt.yaml"

set +x
cat >&2 <<EOF
+ CSM applications and services upgraded
${0##*/}: OK
EOF