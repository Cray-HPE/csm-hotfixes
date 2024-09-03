#!/usr/bin/env bash
#
# MIT License
#
# (C) Copyright 2024 Hewlett Packard Enterprise Development LP
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
set -euo pipefail

ROOT_DIR="$(dirname "${BASH_SOURCE[0]}")"
CMS_IPXE_VERSION='1.15.0-v1-13-0-debug.1+904753f'

source "${ROOT_DIR}/lib/version.sh"
source "${ROOT_DIR}/lib/install.sh"

echo "Loading artifacts into Nexus ... "
"${ROOT_DIR}/lib/setup-nexus.sh"

# Create scratch space
workdir="$(mktemp -d)"
[ -z "${DEBUG:-}" ] && trap 'rm -fr '"${workdir}"'' ERR INT EXIT RETURN || echo "DEBUG was set in environment, $workdir will not be cleaned up."
echo "Applying hotfix: debug  $RELEASE_NAME"
echo "Using temp area: $workdir"

# Build manifest
cat > "${workdir}/manifest.yaml" << EOF
apiVersion: manifests/v1beta1
metadata:
  name: cast-36348
spec:
  sources:
    charts:
    - name: nexus
      type: repo
      location: https://packages.local/repository/charts
  charts:
  - name: cms-ipxe
    source: nexus
    version: $CMS_IPXE_VERSION
    namespace: services
EOF

kubectl -n loftsman get secret site-init -o jsonpath='{.data.customizations\.yaml}' | base64 -d >"${workdir}/customizations.yaml"
manifestgen -c "${workdir}/customizations.yaml" -i "${workdir}/manifest.yaml" -o "${workdir}/deploy-hotfix.yaml"
loftsman ship --manifest-path "${workdir}/deploy-hotfix.yaml"

echo "Updating sysmgmt configmap to use cms-ipxe:${CMS_IPXE_VERSION} ... "
kubectl -n loftsman get cm loftsman-sysmgmt -o jsonpath='{.data.manifest\.yaml}' >"${workdir}/sysmgmt.yaml"
yq4 eval -i '(.spec.charts[] | select(.name == "cms-ipxe") | .version) = "'"$CMS_IPXE_VERSION"'"' "${workdir}/sysmgmt.yaml"
kubectl -n loftsman create cm loftsman-sysmgmt --from-file=manifest.yaml="${workdir}/sysmgmt.yaml" -o yaml --dry-run=client | kubectl apply -f -

set +x
cat >&2 <<EOF
+ Hotfix installed
${0##*/}: OK
EOF
