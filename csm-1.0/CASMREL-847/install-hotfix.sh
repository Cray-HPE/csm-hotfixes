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
# Update cray-kafka-operator
yq w -i "${workdir}/platform.yaml" 'spec.charts.(name==cray-kafka-operator).version' 0.4.2

# get all installed csm version into a file
kubectl get cm -n services cray-product-catalog -o json | jq  -r '.data.csm' | yq r -  -d '*' -j | jq -r 'keys[]' > /tmp/csm_versions
# sort -V: version sort
highest_version=$(sort -V /tmp/csm_versions | tail -1)

if [[ "$highest_version" == "1.0"*  ]];then
    echo "patch 1.0 manifest"
    yq w -i "${workdir}/platform.yaml"  'spec.sources.charts(name==csm).location' https://packages.local/repository/charts
    yq w -i "${workdir}/platform.yaml"  'spec.sources.charts(name==csm).type' repo
    yq w -i "${workdir}/platform.yaml"  'spec.sources.charts(name==csm-algol60).location' https://packages.local/repository/charts
    yq w -i "${workdir}/platform.yaml"  'spec.sources.charts(name==csm-algol60).type' repo
fi

# Load artifacts into nexus
${ROOTDIR}/lib/setup-nexus.sh

function deploy() {
    while [[ $# -gt 0 ]]; do
        loftsman ship --charts-repo https://packages.local/repository/charts --manifest-path "$1"
        shift
    done
}

# Redeploy platform
deploy "${workdir}/platform.yaml"

set +x
cat >&2 <<EOF
+ CSM applications and services upgraded
${0##*/}: OK
EOF