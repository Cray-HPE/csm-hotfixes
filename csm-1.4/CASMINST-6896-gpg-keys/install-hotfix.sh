#!/usr/bin/env bash
#
#  MIT License
#
#  (C) Copyright 2024 Hewlett Packard Enterprise Development LP
#
#  Permission is hereby granted, free of charge, to any person obtaining a
#  copy of this software and associated documentation files (the "Software"),
#  to deal in the Software without restriction, including without limitation
#  the rights to use, copy, modify, merge, publish, distribute, sublicense,
#  and/or sell copies of the Software, and to permit persons to whom the
#  Software is furnished to do so, subject to the following conditions:
#
#  The above copyright notice and this permission notice shall be included
#  in all copies or substantial portions of the Software.
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
#  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
#  OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
#  ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
#  OTHER DEALINGS IN THE SOFTWARE.
#
set -euo pipefail

ROOT_DIR="$(dirname "${BASH_SOURCE[0]}")"
GPG_KEY_FILE_NAME="hpe-signing-key-fips.asc"
CSM_CONFIG_VERSION="1.15.31"

source "${ROOT_DIR}/lib/version.sh"
source "${ROOT_DIR}/lib/install.sh"

function usage {

  cat <<EOF
usage:

./install-hotfix.sh [-k]

Flags:
-k      Only import the GPG keys into the running NCNs, skip all CFS work.
EOF
}

# Get latest CSM release from the product catalog
# or use the CSM_RELEASE environment variable if set
DETECTED_CSM_RELEASE="$(kubectl get cm cray-product-catalog -n services -o jsonpath='{.data.csm}' | yq r -j - | jq -r 'to_entries[] | .key' | sort -V | tail -n 1)"
CSM_RELEASE="${CSM_RELEASE:-$DETECTED_CSM_RELEASE}"
if [ -z "$CSM_RELEASE" ]; then
  echo >&2 "Failed to resolve CSM_RELEASE from cray-product-catalog or from a CSM_RELEASE environment variable. Aborting."
  exit 1
fi

running_system_only=0
while getopts ":k" o; do
  case "${o}" in
  k) running_system_only=1 ;;
  *) usage; exit 2 ;;
  esac
done
shift $((OPTIND - 1))

if [ -f /etc/pit-release ]; then
  echo >&2 'Can not run this hotfix on the PIT node'
  exit 1
else
  readarray -t EXPECTED_NCNS < <(grep -oP 'ncn-[mws]\d+' /etc/hosts | sort -u)
  if [ ${#EXPECTED_NCNS[@]} = 0 ]; then
    echo >&2 "No NCNs found in /etc/hosts! This NCN is not initialized, /etc/hosts should have content."
    exit 1
  fi
fi

export NCNS=()
for ncn in "${EXPECTED_NCNS[@]}"; do
  if ping -c 1 "$ncn" >/dev/null 2>&1; then
    NCNS+=("$ncn")
  else
    echo >&2 "Failed to ping [$ncn]; skipping hotfix for [$ncn]"
  fi
done

function patch_running_ncns {
  local gpg_key_file_name="${GPG_KEY_FILE_NAME}"
  local PDSH_SSH_ARGS_APPEND="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
  local SSH_ARGS="${PDSH_SSH_ARGS_APPEND}"

  for ncn in "${NCNS[@]}"; do
    scp ${SSH_ARGS} "${ROOT_DIR}/keys/${gpg_key_file_name}" "${ncn}:/tmp/${gpg_key_file_name}"
  done

  pdsh -S -b -w "$(printf '%s,' "${NCNS[@]}")" '
    rpm --import /tmp/'"${gpg_key_file_name}"'
    rm -vf /tmp/'"${gpg_key_file_name}"'
  ' || { echo >&2 'Failed to import the new HPE GPG key on one or more nodes!'; return 1; }
}

patch_running_ncns || { echo >&2 'Failed to import the key on one or more running NCNs!'; exit 1; }

if [ "$running_system_only" -eq 1 ]; then
  cat >&2 <<EOF
+ Hotfix installed
${0##*/}: OK
EOF
  exit 0
fi

############################################### CFS ########################################################

workdir="$(mktemp -d)"
[ -z "${DEBUG:-}" ] && trap 'rm -fr '"${workdir}"'' ERR INT EXIT RETURN || echo "DEBUG was set in environment, $workdir will not be cleaned up."

# Update the kubernetes secret with our new GPG key if the new key isn't present
KUBERNETES_SECRET="${KUBERNETES_SECRET:-hpe-signing-key}"
NEW_KEY_PATH="${ROOT_DIR}/keys/${GPG_KEY_FILE_NAME}"
NEW_KEY_SIGNATURE="$(gpg --list-packets "${NEW_KEY_PATH}")"
NEW_KEY_ENCODED="$(base64 -w 0 "${NEW_KEY_PATH}")"
mapfile -t EXISTING_K8S_KEYS < <(kubectl -n services get secret ${KUBERNETES_SECRET} -o jsonpath='{.data}' | jq -r 'keys[]')

KEY_PRESENT=0
for key in "${EXISTING_K8S_KEYS[@]}"; do
  EXISTING_KEY_SIGNATURE="$(kubectl -n services get secret ${KUBERNETES_SECRET} -o jsonpath="{.data.${key/./\\.}}" | base64 -d | gpg --list-packets)"

  if [ "${EXISTING_KEY_SIGNATURE}" = "${NEW_KEY_SIGNATURE}" ]; then
    KEY_PRESENT=1
    break
  fi
done

if [ "${KEY_PRESENT}" -eq 0 ]; then
  echo "Key $GPG_KEY_FILE_NAME is not present, adding it to the secret: ${KUBERNETES_SECRET}"
  kubectl patch secret "${KUBERNETES_SECRET}" -n services -p="{\"data\":{\"${GPG_KEY_FILE_NAME}\":\"${NEW_KEY_ENCODED}\"}}"
else
    echo "Key ${GPG_KEY_FILE_NAME} was already present in Kubernetes secret: ${KUBERNETES_SECRET}"
fi

# Load artifacts into nexus
"${ROOT_DIR}/lib/setup-nexus.sh"

# Create new manifest.
cat >"${workdir}/manifest.yaml" <<EOF
apiVersion: manifests/v1beta1
metadata:
  name: casminst-6896-gpg-keys
spec:
  sources:
    charts:
    - name: nexus
      type: repo
      location: https://packages.local/repository/charts
  charts:
  - name: csm-config
    source: nexus
    version: ${CSM_CONFIG_VERSION}
    namespace: services
EOF

# Merge manifest.
kubectl -n loftsman get secret site-init -o jsonpath='{.data.customizations\.yaml}' | base64 -d >"${workdir}/customizations.yaml"
manifestgen -c "${workdir}/customizations.yaml" -i "${workdir}/manifest.yaml" -o "${workdir}/deploy-hotfix.yaml"

# Deploy chart.
loftsman ship --manifest-path "${workdir}/deploy-hotfix.yaml"

# Update sysmgmt chart.
kubectl -n loftsman get cm loftsman-sysmgmt -o jsonpath='{.data.manifest\.yaml}' >"${workdir}/sysmgmt.yaml"
yq4 eval '(.spec.charts[] | select(.name == "csm-config") | .version) = "'"$CSM_CONFIG_VERSION"'"' "${workdir}/sysmgmt.yaml"
kubectl -n loftsman create cm loftsman-sysmgmt --from-file=manifest.yaml="${workdir}/sysmgmt.yaml" -o yaml --dry-run=client | kubectl apply -f -

# Set credentials for the VCS
PW=$(kubectl -n services get secret vcs-user-credentials -o jsonpath='{.data.vcs_password}' | base64 -d)

# Fetch the latest commit from the specified branch
CSM_CONFIG_COMMIT=$(git ls-remote "https://crayvcs:${PW}@api-gw-service-nmn.local/vcs/cray/csm-config-management.git" "refs/heads/cray/csm/${CSM_CONFIG_VERSION}" | awk '{print $1}')
unset PW

[ -z "$CSM_CONFIG_COMMIT" ] && { echo >&2 "Failed to retrieve the latest commit from csm-config branch cray/csm/${CSM_CONFIG_VERSION}. Aborting."; exit 1; }

# Update cray-product-catalog
CPC_VERSION="1.8.3"
podman run --rm --name ncn-cpc \
  --user root \
  -e PRODUCT=csm \
  -e PRODUCT_VERSION="${CSM_RELEASE}" \
  -e YAML_CONTENT_STRING="{\"configuration\": {\"commit\": \"${CSM_CONFIG_COMMIT}\", \"import_branch\": \"cray/csm/${CSM_CONFIG_VERSION}\"}}" \
  -e KUBECONFIG=/.kube/admin.conf \
  -e VALIDATE_SCHEMA=\"true\" \
  -v /etc/kubernetes:/.kube:ro \
  "registry.local/artifactory.algol60.net/csm-docker/stable/cray-product-catalog-update:${CPC_VERSION}"

### Update CFS configuration ###
load-cfs-config-util

cfs-config-util update-configs --product "csm:${CSM_RELEASE}" \
  --playbook ncn_nodes.yml \
  --playbook ncn-initrd.yml \
  --base-query role=management \
  --save \
  --create-backups \
  --clear-error

rc=$?

if [ $rc -eq 2 ]; then
  echo >&2 "cfs-config-util received invalid arguments."
elif [ $rc -ne 0 ]; then
  echo >&2 "Failed to update CFS configurations. cfs-config-util exited with exit status $rc."
fi

clean-install-deps

# Update the CFS configuration, but do not run it against the NCNs
/usr/share/doc/csm/scripts/operations/configuration/apply_csm_configuration.sh \
  --no-enable --config-name "management-${CSM_RELEASE}"

KUBERNETES_IMAGE_ID="$(kubectl -n services get cm cray-product-catalog -o jsonpath='{.data.csm}' |
  yq r -j - '"'${CSM_RELEASE}'".images' |
  jq -r '. as $o | keys_unsorted[] | select(startswith("secure-kubernetes")) | $o[.].id')"

STORAGE_IMAGE_ID="$(kubectl -n services get cm cray-product-catalog -o jsonpath='{.data.csm}' |
  yq r -j - '"'${CSM_RELEASE}'".images' |
  jq -r '. as $o | keys_unsorted[] | select(startswith("secure-storage")) | $o[.].id')"

if [ -z "$KUBERNETES_IMAGE_ID" ] || [ -z "$STORAGE_IMAGE_ID" ]; then
  echo >&2 "Failed to get image IDs for management-kubernetes-${CSM_RELEASE} or management-storage-${CSM_RELEASE}"
  echo >&2 "Confirm that CSM_RELEASE is set correctly and the images exist in the product catalog."
  exit 1
fi

# Trigger CFS image builds for kubernetes and storage images
TSTAMP=$(date "+%Y%m%d%H%M%S")
K8S_CFS_SESSION_NAME="management-k8s-${CSM_RELEASE}-${TSTAMP}"
CEPH_CFS_SESSION_NAME="management-ceph-${CSM_RELEASE}-${TSTAMP}"

cray cfs sessions create \
  --target-group Management_Master \
  "$KUBERNETES_IMAGE_ID" \
  --target-definition image \
  --target-image-map "$KUBERNETES_IMAGE_ID" "management-kubernetes-${CSM_RELEASE}" \
  --configuration-name "management-${CSM_RELEASE}" \
  --name "${K8S_CFS_SESSION_NAME}" \
  --format json

cray cfs sessions create \
  --target-group Management_Storage \
  "$STORAGE_IMAGE_ID" \
  --target-definition image \
  --target-image-map "$STORAGE_IMAGE_ID" "management-storage-${CSM_RELEASE}" \
  --configuration-name "management-${CSM_RELEASE}" \
  --name "${CEPH_CFS_SESSION_NAME}" \
  --format json

cat >&2 <<EOF
+ Hotfix installed
${0##*/}: OK
EOF
