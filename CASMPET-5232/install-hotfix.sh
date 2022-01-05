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
kubectl -n loftsman get cm loftsman-platform -o jsonpath='{.data.manifest\.yaml}' > "${workdir}/sysmgmt.yaml"
# Update csm-config
yq w -i "${workdir}/sysmgmt.yaml" 'spec.charts.(name==csm-config).version' 1.9.8
# Update bass
yq w -i "${workdir}/sysmgmt.yaml" 'spec.charts.(name==cray-hms-bss).version' 2.0.3

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