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
set -e

ROOT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "${ROOT_DIR}/lib/version.sh"

GPG_KEY_FILE_NAME=hpe-signing-key-fips.asc

function usage {

  cat << EOF
usage:

./install-hotfix.sh [-k]

Flags:
-k      Only import the GPG keys into the running NCNs, skip all CFS work.
EOF
}

running_system_only=0
while getopts ":k" o; do
  case "${o}" in
    y)
      running_system_only=1
      ;;
    *)
      usage
      exit 2
      ;;
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
  if ping -c 1 "$ncn" > /dev/null 2>&1; then
    NCNS+=("$ncn")
  else
    echo >&2 "Failed to ping [$ncn]; skipping hotfix for [$ncn]"
  fi
done

function patch_running_ncns {
  local gpg_key_file_name="${GPG_KEY_FILE_NAME}"

  for ncn in "${NCNS[@]}"; do
    scp "${ROOT_DIR}/keys/${gpg_key_file_name}" "${ncn}:/tmp/${gpg_key_file_name}"
  done

  if ! PDSH_SSH_ARGS_APPEND="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" pdsh -S -b -w "$(printf '%s,' "${NCNS[@]}")" \
  '
  rpm --import /tmp/'"${gpg_key_file_name}"'
  rm -vf /tmp/'"${gpg_key_file_name}"'
  ';  then
    echo >&2 'Failed to import the new HPE GPG key to one or more nodes!'
    return 1
  fi

}

if ! patch_running_ncns; then
  echo >&2 'Failed to import the key to one or more running NCNs!'
  exit 1
fi

if [ "$running_system_only" -eq 1 ]; then
  :
else

  workdir="$(mktemp -d)"
  if [ -z "${DEBUG:-}" ]; then
    trap 'rm -fr '"${workdir}"'' ERR INT EXIT RETURN
  else
    echo "DEBUG was set in environment, $workdir will not be cleaned up."
  fi

  # Update the kubectl secret with our new GPG key
  # FIXME: This does not correctly merge the new key alongside the other keys.
  # FIXME: Fix recursion - re-runs should not append the key again.
  kubectl -n services get secret hpe-signing-key -o jsonpath='{.data}' | base64 -d >"${workdir}/hpe-signing-keys"
  kubectl create secret generic hpe-signing-key -n services --from-file "${workdir}/hpe-signing-keys" --from-file hpe-signing-key --dry-run=client --save-config -o yaml | kubectl apply -f -

  # Create new manifest.
  cat > "${workdir}/manifest.yaml" << EOF
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
    version: 1.16.33
    namespace: services
EOF

  # Merge manifest.
  kubectl -n loftsman get secret site-init -o jsonpath='{.data.customizations\.yaml}' | base64 -d > "${workdir}/customizations.yaml"
  manifestgen -c "${workdir}/customizations.yaml" -i "${workdir}/manifest.yaml" -o "${workdir}/deploy-hotfix.yaml"

  # Load artifacts into nexus
  "${ROOT_DIR}/lib/setup-nexus.sh"

  # Deploy chart.
  loftsman ship --manifest-path "${workdir}/deploy-hotfix.yaml"

  # TODO: Update CFS configuration for the mgmt NCNs. https://github.com/Cray-HPE/docs-csm/blob/release/1.5/upgrade/1.5.2/README.md#update-management-node-cfs-configuration
  # Note: it is not necessary to run CFS against the running nodes, but if it's unavoidable then so be it.
  # TODO: Trigger a CFS image build https://github.com/Cray-HPE/docs-csm/blob/release/1.5/upgrade/1.5.2/README.md#image-customization

fi

cat >&2 << EOF
+ Hotfix installed
${0##*/}: OK
EOF
