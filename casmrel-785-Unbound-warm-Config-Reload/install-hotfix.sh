#!/usr/bin/env bash

# Copyright 2021 Hewlett Packard Enterprise Development LP

set -o errexit
set -o pipefail
set -o xtrace

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")"
source "${ROOTDIR}/lib/version.sh"
source "${ROOTDIR}/scripts/host-record-import.sh"

large_system=false
backup_folder="/tmp/unbound-hotfix-$(date +"%F-%H%M")"

case "$1" in

    "shasta-1.4" | "csm-0.9")
        version="0.3.9"
    ;;
    "shasta-1.5" | "csm-1.0")
        version="0.4.9"
    ;;
    *)
        echo "usage:"
        echo 'install-hotfix.sh "version of shasta or csm" "large-system(optional)"'
        echo ""
        echo "Version of Shasta or CSM can be shasta-[1.3-1.7] or csm-[0.9-1.2]"
        echo "Large systems are systems with more than 3000 computes."
        echo "Examples:"
        echo "./install-hotfix.sh shasta-1.3"
        echo "or"
        echo  "./install-hotfix.sh csm-1.0 large-system"
        exit
    ;;
esac

if [ ! -z "$2" ];then
    case $2 in
        "increase-resources")
            large_system=true
        ;;
        *)
            echo "Did you intend to enable increase-resources settings for cray-dns-unbound"
            echo "Use: '"increase-resources"'"
            exit
        ;;
    esac
fi

# Create scratch space
workdir="$(mktemp -d)"
trap "rm -fr '${workdir}'" EXIT

# Get platform manifest
kubectl -n loftsman get cm loftsman-platform -o jsonpath='{.data.manifest\.yaml}' > "${workdir}/platform.yaml"

# Get core-services manifest
kubectl -n loftsman get cm loftsman-core-services  -o jsonpath='{.data.manifest\.yaml}' > "${workdir}/core-services.yaml"

# make backups
mkdir /tmp/hotfix-unbound
cp "${workdir}/platform.yaml" $backup_folder
cp "${workdir}/core-services.yaml" backup_folder

# Update cray-dns-unbound
yq w -i "${workdir}/core-services.yaml" 'spec.charts.(name==cray-dns-unbound).version' $version
yq w -i "${workdir}/core-services.yaml" 'spec.charts.(name==cray-dns-unbound).values.global.appVersion' $version


if [ "$large_system" = true ] ; then
    yq w -i "${workdir}/core-services.yaml" 'spec.charts.(name==cray-dns-unbound).values.resources.requests.cpu' 4
    yq w -i "${workdir}/core-services.yaml" 'spec.charts.(name==cray-dns-unbound).values.resources.requests.memory' "4Gi"
fi

# update cached imaages in platform
yq w -i "${workdir}/platform.yaml" 'spec.charts.(name==cray-precache-images).values.cacheImages.(.==dtr.dev.cray.com/cray/cray-dns-unbound*)' dtr.dev.cray.com/cray/cray-dns-unbound:"$version"
# get host records from current cray-dns-unbound deploy
check_unbound_records

# check to see if we need to modify loftsman-core-services configmap annotation section

# Load artifacts into nexus
${ROOTDIR}/lib/setup-nexus.sh


export TOKEN=$(curl -s -k -S -d grant_type=client_credentials -d client_id=admin-client -d client_secret=`kubectl get secrets admin-client-auth -o jsonpath='{.data.client-secret}' | base64 -d` https://api-gw-service-nmn.local/keycloak/realms/shasta/protocol/openid-connect/token | jq -r '.access_token')

function deploy() {
    while [[ $# -gt 0 ]]; do
        loftsman ship --charts-repo https://packages.local/repository/charts --manifest-path "$1"
        shift
    done
}

# Redeploy platform
deploy "${workdir}/platform.yaml"

# Redeploy core-services
deploy "${workdir}/core-services.yaml"

annotation_cleanup
set +x
cat >&2 <<EOF
+ CSM applications and services upgraded
${0##*/}: OK
EOF
