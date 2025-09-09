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

set -o errexit
set -o pipefail
set -o xtrace

CHART_VERSION="3.1.13"

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")"
source "${ROOTDIR}/lib/version.sh"

# Create scratch space
workdir="$(mktemp -d)"
trap "rm -fr '${workdir}'" EXIT

echo ">>>>> Loading artifacts into Nexus..."
${ROOTDIR}/lib/setup-nexus.sh

kubectl get secrets -n loftsman site-init -o jsonpath='{.data.customizations\.yaml}' | base64 -d > "${workdir}/customizations.yaml"
kubectl get configmap -n loftsman loftsman-platform -o jsonpath='{.data.manifest\.yaml}' > "${workdir}/iuf.yaml"
manifestgen -i "${workdir}/iuf.yaml" -c "${workdir}/customizations.yaml" -o "${workdir}/platform.yaml"
yq w -i "${workdir}/platform.yaml" 'metadata.name' "iuf"
charts="$(yq r "${workdir}/platform.yaml" 'spec.charts[*].name')"
for chart in $charts; do
    if [[ $chart != "cray-iuf" ]] && [[ $chart != "cray-nls" ]]; then
        yq d -i "${workdir}/platform.yaml" "spec.charts.(name==$chart)"
    fi
done

yq d -i "${workdir}/platform.yaml" "spec.sources"
yq w -i "${workdir}/platform.yaml" 'spec.charts[1].version' "${CHART_VERSION}"
yq w -i "${workdir}/platform.yaml" 'spec.charts[0].version' "${CHART_VERSION}"

yq d -i "${workdir}/platform.yaml" "spec.sources"
yq w -i "${workdir}/platform.yaml" 'spec.charts[1].version' "${CHART_VERSION}"
yq w -i "${workdir}/platform.yaml" 'spec.charts[0].version' "${CHART_VERSION}"

echo ">>>>> The following is the loftsman manifest that will be shipped..."
cat ${workdir}/platform.yaml

echo ">>>>> Ship the loftsman manifest..."
loftsman ship --charts-path ${ROOTDIR}/helm --manifest-path ${workdir}/platform.yaml

set +x
cat >&2 <<EOF
+ Hotfix has been applied. Please proceed to update docs-csm.
${0##*/}: OK
EOF