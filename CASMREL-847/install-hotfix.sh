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
yq w -i "${workdir}/platform.yaml"  'spec.sources.charts(name==csm).location' https://packages.local/repository/charts
yq w -i "${workdir}/platform.yaml"  'spec.sources.charts(name==csm).type' repo
yq w -i "${workdir}/platform.yaml"  'spec.sources.charts(name==csm-algol60).location' https://packages.local/repository/charts
yq w -i "${workdir}/platform.yaml"  'spec.sources.charts(name==csm-algol60).type' repo

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
