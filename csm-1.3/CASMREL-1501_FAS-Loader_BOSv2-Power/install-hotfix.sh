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

# Label for the hotfix Loftsman manifest
HOTFIX_LABEL=casmrel-1501-fas-loader-bos-v2-hotfix

# The following code is included so that this script can be used for future hotfixes and not accidentally use an invalid label.

# This label is used for the manifest, and we append a 15 character timestamp string.
# The result must adhere to K8s naming restrictions:
# * Length <= 253 characters
# * Legal characters: lowercase alphanumeric, -, .
# * Start and end with alphanumeric
#
# Thus HOTFIX_LABEL must be <= 238 characters long, consist of the legal characters
# above, and start with a lowercase alphanumeric.

# Replace _ or whitespace with -
HOTFIX_LABEL=${HOTFIX_LABEL//[_[:space:]]/-}
# Strip any illegal characters
HOTFIX_LABEL=${HOTFIX_LABEL//[^-.a-z0-9]/}
# Strip illegal starting characters from front
HOTFIX_LABEL=${HOTFIX_LABEL##[^a-z0-9]}
# For readability, replace repeated - with a single -
HOTFIX_LABEL=${HOTFIX_LABEL//+(-)/-}
# And similarly for repeated .
HOTFIX_LABEL=${HOTFIX_LABEL//+(.)/.}
# And truncate to 238
HOTFIX_LABEL=${HOTFIX_LABEL::238}
# If after all of this it ends up being blank, then default to the generic "hotfix"
[[ -n ${HOTFIX_LABEL} ]] || HOTFIX_LABEL=hotfix

# Finally, append the timestamp
HOTFIX_LABEL="${HOTFIX_LABEL}-$(date +%Y%m%d%H%M%S)"

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")"
source "${ROOTDIR}/lib/version.sh"

# Create scratch space
workdir="$(mktemp -d)"
trap "rm -fr '${workdir}'" EXIT

# Create base hotfix manifest
base_manifest="${workdir}/base_manifest.yaml"
cat <<EOF > "${base_manifest}"
apiVersion: manifests/v1beta1
metadata:
  name: ${HOTFIX_LABEL}
spec:
  charts:
    - name: cray-hms-firmware-action
      namespace: services
      source: csm-algol60
      values:
        nexus:
          repo: shasta-firmware
        global:
          appVersion: 1.24.1
      version: 2.1.6
    - name: cray-bos
      namespace: services
      source: csm-algol60
      timeout: 10m
      version: 2.0.18
      values:
        global:
          appVersion: 2.0.18
  sources:
    charts:
      - location: https://packages.local/repository/charts
        name: csm-algol60
        type: repo
EOF

# Download customizations.yaml
customizations="${workdir}/customizations.yaml"
kubectl get secrets -n loftsman site-init -o jsonpath='{.data.customizations\.yaml}' | base64 -d > "${customizations}"

# Generate customized manifest
manifest="${workdir}/manifest.yaml"
manifestgen -c "${customizations}" -i "${base_manifest}" -o "${manifest}"

# Load artifacts into nexus
"${ROOTDIR}/lib/setup-nexus.sh"

function deploy() {
    while [[ $# -gt 0 ]]; do
        loftsman ship --charts-repo https://packages.local/repository/charts --manifest-path "$1"
        shift
    done
}

# Redeploy services
deploy "${manifest}"

# Clean up temporary directory
rm -fr "${workdir}"

set +x
cat >&2 <<EOF
+ CSM applications and services upgraded
${0##*/}: OK
EOF
