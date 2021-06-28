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


# Patch core-services manifest
kubectl -n loftsman get cm loftsman-core-services -o jsonpath='{.data.manifest\.yaml}' > "${workdir}/core-services.yaml"
# Update cray-dhcp-kea
yq w -i "${workdir}/core-services.yaml" 'spec.charts.(name==cray-dhcp-kea).version' 0.4.22
# Update cray-dns-unbound
yq w -i "${workdir}/core-services.yaml" 'spec.charts.(name==cray-dns-unbound).version' 0.1.19
yq w -i "${workdir}/core-services.yaml" 'spec.charts.(name==cray-dns-unbound).values.global.appVersion' 0.1.19

# Patch sysmgmt manifest
kubectl -n loftsman get cm loftsman-sysmgmt -o jsonpath='{.data.manifest\.yaml}' > "${workdir}/sysmgmt.yaml"
# Update cray-cfs-operator
yq w -i "${workdir}/sysmgmt.yaml" 'spec.charts.(name==cray-cfs-operator).values.cray-service.containers.cray-cfs-operator.image.tag' 1.10.22
yq w -i "${workdir}/sysmgmt.yaml" 'spec.charts.(name==cray-cfs-operator).values.cray-service.containers.cray-cfs-operator.image.pullPolicy' IfNotPresent
# Update cray-bos
yq w -i "${workdir}/sysmgmt.yaml" 'spec.charts.(name==cray-bos).version' 1.6.22
# Update gitea
yq w -i "${workdir}/sysmgmt.yaml" 'spec.charts.(name==gitea).values.cray-service.persistentVolumeClaims.data-claim.name' data-claim
# Update cray-hms-rts
yq w -i "${workdir}/sysmgmt.yaml" 'spec.charts.(name==cray-hms-rts).version' 1.8.7

# Update the product catalog to report CSM 0.9.4
yq w -i "${workdir}/sysmgmt.yaml" 'spec.charts.(name==csm-config).values.cray-import-config.import_job.CF_IMPORT_PRODUCT_VERSION' "$RELEASE_VERSION"
yq w -i "${workdir}/sysmgmt.yaml" 'spec.charts.(name==csm-config).values.cray-import-config.catalog.image.tag' 0.0.9
yq w -i "${workdir}/sysmgmt.yaml" 'spec.charts.(name==cray-csm-barebones-recipe-install).values.cray-import-kiwi-recipe-image.import_job.PRODUCT_VERSION' "$RELEASE_VERSION"
yq w -i "${workdir}/sysmgmt.yaml" 'spec.charts.(name==cray-csm-barebones-recipe-install).values.cray-import-kiwi-recipe-image.import_job.name' "csm-image-recipe-import-${RELEASE_VERSION}"
yq w -i "${workdir}/sysmgmt.yaml" 'spec.charts.(name==cray-csm-barebones-recipe-install).values.cray-import-kiwi-recipe-image.catalog.image.tag' 0.0.9


# Restart gitea deployment to free previous PVC
kubectl -n services rollout restart deployment gitea-vcs


function deploy() {
    while [[ $# -gt 0 ]]; do
        loftsman ship --charts-repo https://packages.local/repository/charts --manifest-path "$1"
        shift
    done
}

# Redeploy patched manifests
deploy "${workdir}/core-services.yaml" "${workdir}/sysmgmt.yaml"


set +x
cat >&2 <<EOF
+ CSM applications and services upgraded
${0##*/}: OK
EOF
