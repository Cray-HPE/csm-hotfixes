#!/usr/bin/env bash
#
# MIT License
#
# (C) Copyright 2022-2023 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#

set -o errexit
set -o pipefail
set -o xtrace

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")"
source "${ROOTDIR}/lib/version.sh"

# Create scratch space
workdir="$(mktemp -d)"
trap "rm -fr '${workdir}'" EXIT

# Patch sysmgmt manifest
kubectl -n loftsman get cm loftsman-sysmgmt -o jsonpath='{.data.manifest\.yaml}' > "${workdir}/sysmgmt-orig.yaml"
cp "${workdir}/sysmgmt-orig.yaml" "${workdir}/sysmgmt-new.yaml"
# Update cray-hms-firmware-action and cray-bos
yq w -i "${workdir}/sysmgmt-new.yaml" 'spec.charts.(name==cray-hms-firmware-action).version' 2.1.6
yq w -i "${workdir}/sysmgmt-new.yaml" 'spec.charts.(name==cray-hms-firmware-action).values.global.appVersion' 1.24.1
yq w -i "${workdir}/sysmgmt-new.yaml" 'spec.charts.(name==cray-bos).version' 2.0.16
yq w -i "${workdir}/sysmgmt-new.yaml" 'spec.charts.(name==cray-bos).values.global.appVersion' 2.0.16

# get all installed csm version into a file
kubectl get cm -n services cray-product-catalog -o json | jq  -r '.data.csm' | yq r -  -d '*' -j | jq -r 'keys[]' > /tmp/csm_versions
# sort -V: version sort
highest_version=$(sort -V /tmp/csm_versions | tail -1)

if [[ "$highest_version" == "1.0"*  ]];then
    echo "patch 1.0 manifest"
    yq w -i "${workdir}/sysmgmt-new.yaml"  'spec.sources.charts(name==csm).location' https://packages.local/repository/charts
    yq w -i "${workdir}/sysmgmt-new.yaml"  'spec.sources.charts(name==csm).type' repo
    yq w -i "${workdir}/sysmgmt-new.yaml"  'spec.sources.charts(name==csm-algol60).location' https://packages.local/repository/charts
    yq w -i "${workdir}/sysmgmt-new.yaml"  'spec.sources.charts(name==csm-algol60).type' repo
fi

# convert to JSON for simpler Python-ing
yq r -j "${workdir}/sysmgmt-new.yaml" > "${workdir}/sysmgmt-new.json"

python3 -c "
import json

with open('${workdir}/sysmgmt-new.json', 'rt') as f:
  manifest = json.load(f)

chart_list = manifest['spec']['charts']
manifest['spec']['charts'] = [ c for c in chart_list if c['name'] in { 'cray-hms-firmware-action', 'cray-bos' } ]

with open('${workdir}/sysmgmt-new.json', 'wt') as f:
  json.dump(manifest, f)
"

# convert back to YAML and lose the -new suffix
yq r -P "${workdir}/sysmgmt-new.json" > "${workdir}/sysmgmt.yaml"

# Load artifacts into nexus
${ROOTDIR}/lib/setup-nexus.sh

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
