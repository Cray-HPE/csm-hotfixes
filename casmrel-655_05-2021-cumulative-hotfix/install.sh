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

# Update /etc/hosts on ncn workers
update_host_records

# update kea traffic policy
update_kea_traffic_policy

# Get the systems customizations.yaml
kubectl get secrets -n loftsman site-init -o jsonpath='{.data.customizations\.yaml}' | base64 -d > "${workdir}/customizations.yaml"

# Add customizations to the hotfix manifest.yaml
manifestgen -i ./manifests/casmrel-655.yaml -c "${workdir}/customizations.yaml" -o "${workdir}/casmrel-655.yaml" 

load-install-deps

# Sync container images to Nexus registry
skopeo-sync "${ROOTDIR}/docker"

# Sync charts to Nexus registry
nexus-upload helm "${ROOTDIR}/helm" "${CHARTS_REPO:-"charts"}"

# Deploy the hotfix manifest
loftsman ship --charts-repo https://packages.local/repository/charts --manifest-path "${workdir}/casmrel-655.yaml"

clean-install-deps

mkdir -p /opt/cray/ncn
cp ./set-bmc-ntp-dns.sh /opt/cray/ncn/
chmod 755 /opt/cray/ncn/set-bmc-ntp-dns.sh

echo "install.sh has completed"
