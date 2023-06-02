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
source "${ROOTDIR}/lib/hotfixes.sh"

# Label for the hotfix Loftsman manifest
HOTFIX_LABEL=$(make_hotfix_label casmrel-1501-fas-loader-bos-v2-hotfix)

# Charts to deploy
CHART_NAMES=( cray-bos cray-hms-firmware-action )

# Create scratch space
workdir="$(mktemp -d)"
trap "rm -fr '${workdir}'" EXIT

get_latest_charts

# Update each chart manifest with the hotfix information, or create a default hotfix chart manifest if one was not found

# cray-bos
chart=cray-bos
chart_file="${workdir}/${chart}.yaml"
if [[ ! -e ${chart_file} ]]; then
    # Create a default manifest for this chart
    cat <<EOF > "${chart_file}"
name: ${chart}
namespace: services
source: csm-algol60
timeout: 10m
version: 2.0.16
values:
  global:
    appVersion: 2.0.16
EOF
else
    # Update the manifest for the hotfix    
    yq w -i "${chart_file}" 'version' 2.0.16
    yq w -i "${chart_file}" 'values.global.appVersion' 2.0.16
fi

# cray-hms-firmware-action
chart=cray-hms-firmware-action
chart_file="${workdir}/${chart}.yaml"
if [[ ! -e ${chart_file} ]]; then
    # Create a default manifest for this chart
    cat <<EOF > "${chart_file}"
name: cray-hms-firmware-action
namespace: services
source: csm-algol60
values:
  nexus:
    repo: shasta-firmware
  global:
    appVersion: 1.24.1
version: 2.1.6
EOF
else
    # Update the manifest for the hotfix
    yq w -i "${chart_file}" 'version' 2.1.6
    yq w -i "${chart_file}" 'values.global.appVersion' 1.24.1
fi

# Add individual chart files into manifest. Result is stored in $manifest_file variable
merge_charts_into_manifest

cat "${manifest_file}"

# Load artifacts into nexus
${ROOTDIR}/lib/setup-nexus.sh

function deploy() {
    while [[ $# -gt 0 ]]; do
        loftsman ship --charts-repo https://packages.local/repository/charts --manifest-path "$1"
        shift
    done
}

# Redeploy services
deploy  "${manifest_file}"

# Clean up temporary directory
rm -fr "${workdir}"

set +x
cat >&2 <<EOF
+ CSM applications and services upgraded
${0##*/}: OK
EOF
