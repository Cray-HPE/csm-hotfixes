#!/usr/bin/env bash

# Copyright 2023 Hewlett Packard Enterprise Development LP

set -o errexit
set -o pipefail
set -o xtrace

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")"
source "${ROOTDIR}/lib/version.sh"

# Create scratch space
workdir="$(mktemp -d)"
trap "rm -fr '${workdir}'" EXIT


# Patch sysmgmt manifest
kubectl -n loftsman get cm loftsman-sysmgmt -o jsonpath='{.data.manifest\.yaml}' > "${workdir}/sysmgmt.yaml"
# Update cray-bos
yq w -i "${workdir}/sysmgmt.yaml" 'spec.charts.(name==cray-bos).version' 2.0.12


function deploy() {
    while [[ $# -gt 0 ]]; do
        loftsman ship --charts-repo https://packages.local/repository/charts --manifest-path "$1"
        shift
    done
}

# Redeploy sysmgmt
deploy "${workdir}/sysmgmt.yaml"


set +x
cat >&2 <<EOF
+ CSM applications and services upgraded
${0##*/}: OK
EOF
