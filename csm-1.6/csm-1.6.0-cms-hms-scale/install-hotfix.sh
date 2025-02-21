#!/usr/bin/env bash
#
# MIT License
#
# (C) Copyright 2025 Hewlett Packard Enterprise Development LP
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

ROOTDIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")

REPO_LIST=$(cd "${ROOTDIR}/rpm" ; ls | tr '\n' ' ')

function usage {

cat << EOF
usage:

./install-hotfix.sh

EOF
}

source "${ROOTDIR}/lib/version.sh"

# Create scratch space
workdir="$(mktemp -d)"
trap "rm -fr '${workdir}'" EXIT

# Build manifest
cat > "${workdir}/manifest.yaml" << EOF
apiVersion: manifests/v1beta1
metadata:
  name: csm-1.6.0-cms-hms-scale-hotfix
spec:
  charts:
  - name: cray-hms-smd
    version: 7.1.19
    namespace: services
    values:
      cray-service:
        sqlCluster:
          resources:
            requests:
              cpu: "4"
              memory: 8Gi
  - name: cray-hms-firmware-action
    version: 3.1.10
    namespace: services
  - name: cray-hms-hmcollector
    version: 2.16.8
    namespace: services
  - name: cray-power-control
    version: 2.1.10
    namespace: services
    timeout: 10m
  - name: cray-bos
    version: 2.30.8
    namespace: services
    timeout: 10m
EOF

# Extract customizations.yaml
kubectl -n loftsman get secret site-init -o jsonpath='{.data.customizations\.yaml}' | base64 -d > "${workdir}/customizations.yaml"

# manifestgen
manifestgen -c "${workdir}/customizations.yaml" -i "${workdir}/manifest.yaml" -o "${workdir}/deploy-hotfix.yaml"

# Load artifacts into nexus
patch_services=Y patch_rpms=N "${ROOTDIR}/lib/setup-nexus.sh"

# Deploy chart
loftsman ship --manifest-path "${workdir}/deploy-hotfix.yaml" --charts-path "${ROOTDIR}/helm"

set +x
cat >&2 <<EOF
+ Hotfix installed
${0##*/}: OK
EOF
