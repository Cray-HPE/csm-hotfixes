#!/usr/bin/env bash

# Copyright 2021 Hewlett Packard Enterprise Development LP

set -o errexit
set -o pipefail
set -o xtrace


# Create scratch space
workdir="$(mktemp -d)"
trap "rm -fr '${workdir}'" EXIT


# Patch core-services manifest
kubectl -n loftsman get cm loftsman-core-services -o jsonpath='{.data.manifest\.yaml}' > "${workdir}/core-services.yaml"
# Update cray-dhcp-kea
yq w -i "${workdir}/core-services.yaml" 'spec.charts.(name==cray-dhcp-kea).version' 0.4.22
# Update cray-dns-unbound
yq w -i "${workdir}/core-services.yaml" 'spec.charts.(name==cray-dns-unbound).version' 0.1.18
yq w -i "${workdir}/core-services.yaml" 'spec.charts.(name==cray-dns-unbound).values.global.appVersion' 0.1.18

# Patch sysmgmt manifest
kubectl -n loftsman get cm loftsman-sysmgmt -o jsonpath='{.data.manifest\.yaml}' > "${workdir}/sysmgmt.yaml"
# Update cray-cfs-operator
yq w -i "${workdir}/sysmgmt.yaml" 'spec.charts.(name==cray-cfs-operator).values.cray-service.containers.cray-cfs-operator.image.tag' 1.10.22
yq w -i "${workdir}/sysmgmt.yaml" 'spec.charts.(name==cray-cfs-operator).values.cray-service.containers.cray-cfs-operator.image.pullPolicy' IfNotPresent
# Update cray-bos
yq w -i "${workdir}/sysmgmt.yaml" 'spec.charts.(name==cray-bos).version' 1.6.22
# Update gitea
yq w -i "${workdir}/sysmgmt.yaml" 'spec.charts.(name==gitea).values.cray-service.persistentVolumeClaims.data-claim.name' data-claim

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
