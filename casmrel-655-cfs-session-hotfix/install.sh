#!/usr/bin/env bash
set -o errexit
set -o pipefail
set -o xtrace

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")"
source "${ROOTDIR}/lib/install.sh"
source "${ROOTDIR}/update_host_records.sh"

# Create scratch space
workdir="$(mktemp -d)"
trap "rm -fr '${workdir}'" EXIT

# update /etc/hosts on ncn workers
update_host_records

# Get installed sysmgmt manifest, which includes customizations
kubectl get cm -n loftsman loftsman-sysmgmt -o jsonpath='{.data.manifest\.yaml}'  > "${workdir}/sysmgmt.yaml"

# Get installed core-services manifest, which includes customizations
kubectl get cm -n loftsman loftsman-core-services -o jsonpath='{.data.manifest\.yaml}'  > "${workdir}/core-services.yaml"

# Add hotfix changes to cray-cfs-operator chart
yq w -i "${workdir}/sysmgmt.yaml" 'spec.charts.(name==cray-cfs-operator).values.cray-service.containers.cray-cfs-operator.image.tag' 1.10.22
yq w -i "${workdir}/sysmgmt.yaml" 'spec.charts.(name==cray-cfs-operator).values.cray-service.containers.cray-cfs-operator.image.pullPolicy' IfNotPresent

# add hotifx changes to cray-dns-unbound
yq w -i "${workdir}/core-services.yaml" 'spec.charts.(name==cray-dns-unbound).version' 0.1.18
yq w -i "${workdir}/core-services.yaml" 'spec.charts.(name==cray-dns-unbound).values.global.appVersion' 0.1.18

load-install-deps

# Sync container images to Nexus registry
skopeo-sync "${ROOTDIR}/docker"

# Sync charts to Nexus registry
nexus-upload helm "${ROOTDIR}/helm" "${CHARTS_REPO:-"charts"}"

# Deploy fixed sysmgmt manifest
loftsman ship --charts-repo https://packages.local/repository/charts --manifest-path "${workdir}/sysmgmt.yaml"

# Deploy fixed core-services manifest
loftsman ship --charts-repo https://packages.local/repository/charts --manifest-path "${workdir}/core-services.yaml"

clean-install-deps

mkdir -p /opt/cray/ncn
cp ./set-bmc-ntp-dns.sh /opt/cray/ncn/
chmod 755 /opt/cray/ncn/set-bmc-ntp-dns.sh

echo "Please run '/opt/cray/ncn/set-bmc-ntp-dns.sh -h'"
