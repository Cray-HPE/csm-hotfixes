#!/bin/bash
#
# MIT License
#
# (C) Copyright 2024-2025 Hewlett Packard Enterprise Development LP
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
LOG_DIR=/var/log/hotfix-kdump
CURRENT_LOG_DIR="${LOG_DIR}/$(date '+%Y-%m-%d_%H:%M:%S')"
mkdir -p "${CURRENT_LOG_DIR}"
exec 19> "${CURRENT_LOG_DIR}/patch.xtrace"
export BASH_XTRACEFD="19"

function usage {

  cat << EOF
Modifies the "crashkernel" boot parameter(s) for each NCN; in BSS, and in the on-disk bootloader.
usage:

./$0.sh

EOF
}

CSM_PATH="${CSM_PATH:-}"
while getopts ":" o; do
  case "${o}" in
    *)
      usage
      exit 2
      ;;
  esac
done
shift $((OPTIND - 1))


ROOT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "${ROOT_DIR}/lib/version.sh"
echo "Installing runtime hotfix: $RELEASE_NAME-$RELEASE_VERSION"

trap 'echo "See ${CURRENT_LOG_DIR}/patch.xtrace for debug output."' ERR INT
set -eu
set -o errexit
set -o pipefail
set -o xtrace
if [ -f /etc/pit-release ]; then
  echo >&2 'Can not run this hotfix on the PIT node'
  exit 1
fi

function update-disk-bootloaders {
  local error=9
  local expected_ncns
  local ncns=()
  expected_ncns=( "$@" )

  printf "Checking reachability for [%s] NCN(s) ... " ${#expected_ncns[@]}
  for ncn in "${expected_ncns[@]}"; do
    if ping -c 1 "$ncn" >/dev/null 2>&1 ; then
      ncns+=( "$ncn" )
    else
      echo >&2 "Failed to ping [$ncn]; skipping on-disk bootloader hotfix for [$ncn]"
    fi
  done
  echo "Done"
  echo "${#ncns[@]} of ${#expected_ncns[@]} were reachable."
  printf "Patching disk bootloaders on %s NCN(s) ... \n" "${#ncns[@]}"
  if ! PDSH_SSH_ARGS_APPEND="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" pdsh -S -b -w "$(printf '%s,' "${ncns[@]}")" '
    kdump_blacklist=( aesni_intel br_netfilter bridge cxi_core mlx5_core mlx5_ib qed qede qedf qedi sunrpc xhci_hcd )
    echo "Blacklisting kernel modules from the kdump initrd ... "
    for module in "${kdump_blacklist[@]}"; do
     if ! grep '\''^KDUMP_COMMANDLINE_APPEND='\'' /etc/sysconfig/kdump | grep -q "$module"; then
      sed -i -E '\''s/(KDUMP_COMMANDLINE_APPEND=")/\1'\''"$module"'\'',/'\'' /etc/sysconfig/kdump
     fi
    done

    echo "Rebuilding kdump initrd ... "
    . /srv/cray/scripts/common/dracut-lib.sh
    if [ -f /boot/initrd-${KVER}-kdump ]; then
      rm -f /boot/initrd-${KVER}-kdump
    fi
    if [ -f /var/lib/kdump/initrd ]; then
      rm -f /var/lib/kdump/initrd
    fi
    systemctl restart kdump.service

    echo "Patching grub bootloader with new crashkernel parameters."
    if ! mount -L BOOTRAID 2>/dev/null; then
      echo "BOOTRAID already mounted"
    fi
    BOOTRAID="$(lsblk -o MOUNTPOINT -nr /dev/disk/by-label/BOOTRAID)"
    if [ ! -f "$BOOTRAID/boot/grub2/grub.cfg" ]; then
      echo >&2 "Missing grub.cfg! $BOOTRAID/boot/grub2/grub.cfg was not found."
      exit 1
    fi
    if grep -q "crashkernel=72M,low" "$BOOTRAID/boot/grub2/grub.cfg" && grep -q "crashkernel=512M,high" "$BOOTRAID/boot/grub2/grub.cfg"; then
     echo "Expected crashkernel parameters are already present."
    else
      printf "Creating grub2 backup at %s ... " "$BOOTRAID/boot/grub2/grub.cfg"
      cp "$BOOTRAID/boot/grub2/grub.cfg" "$BOOTRAID/boot/grub2/grub.cfg.pre-patch"
      echo "Done"
      printf "Patching disk bootloader ... "

      sed -i -E "s/crashkernel=[0-9]+[a-zA-Z]?//g" "$BOOTRAID/boot/grub2/grub.cfg"

      sed -i -E '\''s/(crashkernel=)[0-9]+[a-zA-Z]/\1512M,high \172M,low/'\'' "$BOOTRAID/boot/grub2/grub.cfg"
      echo "Done"
    fi
  ' | dshbak -c ; then
      echo >&2 "Failed to update the crashkernel bootparemeter on one or more nodes' disk bootloaders."
      return 1
  fi
  echo 'Done. All disk-bootloaders for all reachable NCNs were successfully patched.'
}

printf "Determining NCN inventory ... "
readarray -t EXPECTED_NCNS < <(grep -oP 'ncn-[mws]\d+' /etc/hosts | sort -u)
if [ ${#EXPECTED_NCNS[@]} = 0 ]; then
  echo >&2 "No NCNs found in /etc/hosts! This NCN is not initialized, /etc/hosts should have content."
  exit 1
fi
echo 'Done'
echo "Found: [${#EXPECTED_NCNS[@]}] NCN(s)"
if ! update-disk-bootloaders "${EXPECTED_NCNS[@]}"; then
  echo >&2 'Failed to update one or more disk bootloaders. Aborting.'
  exit 1
fi

function update-bss {
  local error=0
  local ncn_xnames
  ncn_xnames=("$@")
  mkdir -p "${CURRENT_LOG_DIR}"
  echo "Patching BSS bootparameters for [${#ncn_xnames[@]}] NCNs."

  for ncn_xname in "${ncn_xnames[@]}"; do
    printf "%-16s - Backing up BSS bootparameters to %s/%s.bss.backup.json ... " "${ncn_xname}" "${CURRENT_LOG_DIR}" "${ncn_xname}"
    cray bss bootparameters list --hosts "${ncn_xname}" --format json | jq '.[0]' > "${CURRENT_LOG_DIR}/${ncn_xname}.bss.backup.json"
    echo 'Done'
    if grep -q 'crashkernel=72M,low' "${CURRENT_LOG_DIR}/${ncn_xname}.bss.backup.json" && grep -q 'crashkernel=512M,high' "${CURRENT_LOG_DIR}/${ncn_xname}.bss.backup.json"; then
      printf "%-16s - Was already patched in BSS. Skipping. \n" "${ncn_xname}"
      continue
    fi
    printf "%-16s - Creating %s/%s.bss.patched.json ... " "${ncn_xname}" "${CURRENT_LOG_DIR}" "${ncn_xname}"

    # Purge any and all "crashkernel" entries to prevent duplicates or weird diverged modifications.
    sed -E 's/crashkernel=[0-9]+[a-zA-Z]? //g' "${CURRENT_LOG_DIR}/${ncn_xname}.bss.backup.json" > "${CURRENT_LOG_DIR}/${ncn_xname}.bss.scrubbed.json"

    # Apply the new settings.
    jq '.params+=" crashkernel=512M,high crashkernel=72M,low"' "${CURRENT_LOG_DIR}/${ncn_xname}.bss.scrubbed.json" > "${CURRENT_LOG_DIR}/${ncn_xname}.bss.patched.json"
    echo 'Done'
    printf "%-16s - Committing %s/%s.bss.patched.json ... " "${ncn_xname}" "${CURRENT_LOG_DIR}" "${ncn_xname}"

    if ! curl -s -f -k -H "Authorization: Bearer ${TOKEN}" -X PUT \
      https://api-gw-service-nmn.local/apis/bss/boot/v1/bootparameters \
      --data @"${CURRENT_LOG_DIR}/${ncn_xname}.bss.patched.json"; then
      echo >&2 'Failed!'
      error=1
    else
      echo 'Done'
    fi
  done
  return "$error"
}

error=0
export TOKEN=$(curl -k -s -S -d grant_type=client_credentials \
      -d client_id=admin-client \
      -d client_secret=`kubectl get secrets admin-client-auth -o jsonpath='{.data.client-secret}' | base64 -d` \
      https://api-gw-service-nmn.local/keycloak/realms/shasta/protocol/openid-connect/token | jq -r '.access_token')
echo 'Working on ncn-master nodes ...'
if IFS=$'\n' read -rd '' -a NCN_XNAMES; then
  :
fi <<< "$(cray hsm state components list --role Management --subrole Master --type Node --format json | jq -r '.Components | map(.ID) | join("\n")')"
if ! update-bss "${NCN_XNAMES[@]}"; then
  echo >&2 "Failed to update one or more NCN master nodes."
  error=1
fi

echo 'Working on ncn-worker nodes ...'
if IFS=$'\n' read -rd '' -a NCN_XNAMES; then
  :
fi <<< "$(cray hsm state components list --role Management --subrole Worker --type Node --format json | jq -r '.Components | map(.ID) | join("\n")')"
if ! update-bss "${NCN_XNAMES[@]}"; then
  echo >&2 "Failed to update one or more NCN worker nodes."
  error=1
fi

echo 'Working on ncn-storage nodes ...'
if IFS=$'\n' read -rd '' -a NCN_XNAMES; then
  :
fi <<< "$(cray hsm state components list --role Management --subrole Storage --type Node --format json | jq -r '.Components | map(.ID) | join("\n")')"
if ! update-bss "${NCN_XNAMES[@]}"; then
  echo >&2 "Failed to update one or more NCN storage nodes."
  error=1
fi

if [ "$error" -eq 0 ]; then
cat >&2 << EOF
+ Hotfix installed
${0##*/}: OK
EOF
else
cat >&2 << EOF
+ Hotfix failed to install; see $CURRENT_LOG_DIR for clues.
${0##*/}: NOT OK
EOF
fi
