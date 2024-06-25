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
#  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES, OR
#  OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
#  ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
#  OTHER DEALINGS IN THE SOFTWARE.
#

set -eo pipefail

ROOT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "${ROOT_DIR}/lib/install.sh"
source "${ROOT_DIR}/lib/version.sh"

function usage {
  cat << EOF
Usage: $0 [-v]

Flags:
  -v    Verbose (run with set -x).
EOF
}

while getopts "v" opt; do
  case "${opt}" in
    v) 
      set -x;
      ;;
    *) usage;
       exit 2
       ;;
  esac
done

if [[ -f /etc/pit-release ]]; then
  echo >&2 "Cannot run this hotfix on the PIT node"
  exit 1
fi

EXPECTED_NCNS=($(grep -oP 'ncn-[mws]\d+' /etc/hosts | sort -u))
if [[ ${#EXPECTED_NCNS[@]} -eq 0 ]]; then
  echo >&2 "No NCNs found in /etc/hosts! This NCN is not initialized, /etc/hosts should have content."
  exit 1
fi

NCNS=()
for ncn in "${EXPECTED_NCNS[@]}"; do
  if ping -c 1 "$ncn" >/dev/null 2>&1; then
    NCNS+=("$ncn")
  else
    echo >&2 "Failed to ping [$ncn]; skipping hotfix for [$ncn]"
  fi
done

if [[ ${#NCNS[@]} -eq 0 ]]; then
  echo >&2 "No reachable NCNs found"
  exit 1
fi

echo "Importing DST GPG key on [${#NCNS[@]}] running NCNs"
GPG_KEY_ID="hpe-signing-key-fips.asc"

# Push gpg key to the NCNs
for ncn in "${NCNS[@]}"; do
  ssh-keyscan -H "${ncn}" 2>/dev/null >> ~/.ssh/known_hosts || {
    echo >&2 "Failed to add $ncn to known hosts"
    continue
  }
  scp "${ROOT_DIR}/${GPG_KEY_ID}" "${ncn}:/tmp/" || {
    echo >&2 "Failed to copy GPG key to $ncn"
    continue
  }
done

# Import gpg key on the NCN
NCNS_STR=$(IFS=','; echo "${NCNS[*]}")
if ! pdsh -w "${NCNS_STR}" "rpm --import /tmp/${GPG_KEY_ID}"; then
  echo "GPG key import failed on one or more NCNs."
  exit 1
else
  echo "GPG key import completed successfully on all NCNs."
fi

# Fetch, patch and upload base images
echo "Patching base images in IMS."

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

IMAGES=$(kubectl -n services get cm cray-product-catalog -o jsonpath='{.data.csm}' 2>/dev/null | \
         yq r -j - | \
         jq -r '."1.5.2".images | with_entries(select(.key | test("secure-(kubernetes|storage-ceph)"))) | map_values(.id)')

DATE=$(date +%Y%m%d)
for rootfs in $(jq -r 'keys_unsorted[]' <<< "${IMAGES}"); do
  image_id=$(jq -r --arg key "${rootfs}" '.[$key]' <<< "${IMAGES}")
  cray artifacts get boot-images "${image_id}/kernel" "${TEMP_DIR}/${image_id}.kernel"
  cray artifacts get boot-images "${image_id}/initrd" "${TEMP_DIR}/${image_id}.initrd"
  cray artifacts get boot-images "${image_id}/rootfs" "${TEMP_DIR}/${rootfs}"

  unsquashfs -d "${TEMP_DIR}/unsquashed-${rootfs}" "${TEMP_DIR}/${rootfs}"
  cp "${ROOT_DIR}/${GPG_KEY_ID}" "${TEMP_DIR}/unsquashed-${rootfs}/tmp/"
  chroot "${TEMP_DIR}/unsquashed-${rootfs}" rpm --import "/tmp/${GPG_KEY_ID}"
  rm -f "${TEMP_DIR}/unsquashed-${rootfs}/tmp/${GPG_KEY_ID}"
  mksquashfs "${TEMP_DIR}/unsquashed-${rootfs}" "${TEMP_DIR}/${rootfs}-${DATE}" -no-xattrs -comp gzip -no-exports -noappend -no-recovery -processors "$(nproc)"

  ${ROOT_DIR}/init-ims-image.sh \
      -b boot-images \
      -n "${rootfs}-${DATE}" \
      -k "${TEMP_DIR}/${image_id}.kernel" \
      -i "${TEMP_DIR}/${image_id}.initrd" \
      -r "${TEMP_DIR}/${rootfs}-${DATE}"
done

cat >&2 <<EOF
+ Hotfix installed
${0##*/}: OK
EOF

