#!/usr/bin/env bash
set -o errexit
set -o pipefail
set -o xtrace

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")"
source "${ROOTDIR}/lib/install.sh"

# Create scratch space
workdir="$(mktemp -d)"
trap "rm -fr '${workdir}'" EXIT

# Get installed sysmgmt manifest, which includes customizations
kubectl get cm -n loftsman loftsman-sysmgmt -o jsonpath='{.data.manifest\.yaml}'  > "${workdir}/sysmgmt.yaml"

# Add hotfix changes to cray-cfs-operator chart
yq w -i "${workdir}/sysmgmt.yaml" 'spec.charts.(name==cray-cfs-operator).values.cray-service.containers.cray-cfs-operator.image.tag' 1.10.22
yq w -i "${workdir}/sysmgmt.yaml" 'spec.charts.(name==cray-cfs-operator).values.cray-service.containers.cray-cfs-operator.image.pullPolicy' IfNotPresent

load-install-deps

# Sync container images to Nexus registry
skopeo-sync "${ROOTDIR}/docker"

# Deploy fixed sysmgmt manifest
loftsman ship --charts-repo https://packages.local/repository/charts --manifest-path "${workdir}/sysmgmt.yaml"

clean-install-deps