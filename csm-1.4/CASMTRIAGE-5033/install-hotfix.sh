#!/usr/bin/env bash
#
#  MIT License
#
#  (C) Copyright 2023 Hewlett Packard Enterprise Development LP
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
LOG_DIR=/var/log/qlogic-hotfix
CURRENT_LOG_DIR="${LOG_DIR}/$(date '+%Y-%m-%d_%H:%M:%S')"
mkdir -p "${CURRENT_LOG_DIR}"
exec 19>"${CURRENT_LOG_DIR}/patch.xtrace"
export BASH_XTRACEFD="19"

ROOT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "${ROOT_DIR}/lib/version.sh"

# Load artifacts into nexus
"${ROOT_DIR}/lib/setup-nexus.sh"

trap 'echo "See ${CURRENT_LOG_DIR}/patch.xtrace for debug output."' ERR INT
set -eu
set -o errexit
set -o pipefail
set -o xtrace
if [ -f /etc/pit-release ]; then
    echo >&2 'Can not run this hotfix on the PIT node'
    exit 1
else
    readarray -t EXPECTED_NCNS < <(grep -oP 'ncn-[mw]\d+' /etc/hosts | sort -u)
    if [ ${#EXPECTED_NCNS[@]} = 0 ]; then
        echo >&2 "No NCNs found in /etc/hosts! This NCN is not initialized, /etc/hosts should have content."
        exit 1
    fi
fi
if [ "${1:-}" != 'upload-only' ]; then

    export NCNS=()
    for ncn in "${EXPECTED_NCNS[@]}"; do
        if ping -c 1 "$ncn" >/dev/null 2>&1 ; then
            NCNS+=( "$ncn" )
        else
            echo >&2 "Failed to ping [$ncn]; skipping hotfix for [$ncn]"
        fi
    done

    echo "Applying the qlogic driver patch to [${#NCNS[@]}] NCNs (workers and masters only) ... "

    export PDSH_SSH_ARGS_APPEND="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
    if ! pdsh -S -b -w "$(printf '%s,' "${NCNS[@]}")" '
    sle_version="sle-$(awk -F= '\''/VERSION=/{gsub(/["-]/, "") ; print tolower($NF)}'\'' /etc/os-release)"
    zypper --no-gpg-checks --plus-repo "https://packages.local/repository/casmtriage-5033-${sle_version}" in -y qlgc-fastlinq-kmp-default

    rm -f /squashfs/*

    # Comment out the kdump removal, you never know when the system will crash in general and we may need it to exist in this small amount of time.
    sed -i -E "s:(rm -f /boot/initrd-\*-kdump):#\1:" /srv/cray/scripts/common/create-ims-initrd.sh

    echo -n "Generating new initrd ... "
    /srv/cray/scripts/common/create-ims-initrd.sh >/squashfs/build.log 2>/dev/build.error.log

    # Restore the script back to its original, intended state.
    cp /run/rootfsbase/srv/cray/scripts/common/create-ims-initrd.sh /srv/cray/scripts/common/create-ims-initrd.sh

    echo "Done"
    if ! mount -L BOOTRAID 2>/dev/null; then
        echo "BOOTRAID already mounted"
    fi

    # Update the local disk bootloader.
    BOOTRAID="$(lsblk -o MOUNTPOINT -nr /dev/disk/by-label/BOOTRAID)"
    initrd_name="$(awk -F"/" "/initrdefi/{print \$NF}" "$BOOTRAID/boot/grub2/grub.cfg")"
    cp -pv /squashfs/initrd.img.xz "$BOOTRAID/boot/$initrd_name"
    cp -pv /squashfs/*.kernel "$BOOTRAID/boot/kernel"
    '; then
        echo >&2 'Failed to apply the new driver, or at least update the disk bootloader with the patch on one or more nodes.'
        exit 1
    fi
fi

bucket=boot-images
fixed_kernel_object=k8s/qlogic-update/kernel
fixed_initrd_object=k8s/qlogic-update/initrd
function update-bss() {
    local ncn_xnames
    ncn_xnames=( "$@" )
    mkdir -p "${CURRENT_LOG_DIR}"
    echo "Patching BSS bootparameters for [${#ncn_xnames[@]}] NCNs."

    for ncn_xname in "${ncn_xnames[@]}"; do
        printf '%-16s Current kernel and initrd settings:\n' "$ncn_xname"
        cray bss bootparameters list --hosts "${ncn_xname}" --format json | jq '.[] | .initrd, .kernel'
        echo "----------------"
    done

    for ncn_xname in "${ncn_xnames[@]}"; do
        printf "%-16s - Backing up BSS bootparameters to %s/%s.bss.backup.json ... " "${ncn_xname}" "${CURRENT_LOG_DIR}" "${ncn_xname}"
        cray bss bootparameters list --hosts "${ncn_xname}" --format json | jq '.[]' >"${CURRENT_LOG_DIR}/${ncn_xname}.bss.backup.json"
        echo 'Done'
        printf '%-16s - Patching BSS bootparameters ... ' "${ncn_xname}"
        cray bss bootparameters update --hosts "${ncn_xname}" --kernel "s3://${bucket}/${fixed_kernel_object}" >/dev/null 2>&1
        cray bss bootparameters update --hosts "${ncn_xname}" --initrd "s3://${bucket}/${fixed_initrd_object}" >/dev/null 2>&1
        echo 'Done'
    done

    for ncn_xname in "${ncn_xnames[@]}"; do
        printf '%-16s New kernel and initrd settings:\n' "$ncn_xname"
        cray bss bootparameters list --hosts "${ncn_xname}" --format json | jq '.[] | .initrd, .kernel'
        echo "----------------"
    done
}

upload_error=0
echo -n "Uploading new kernel from $(hostname) to s3://${bucket}/${fixed_kernel_object} ... "
if ! cray artifacts create "$bucket" "$fixed_kernel_object" /squashfs/*.kernel >"${CURRENT_LOG_DIR}/kernel.upload.log" 2>&1 ; then
    upload_error=1
    echo >&2 'Failed!'
else
    echo 'Done'
fi
echo -n "Uploading new initrd from $(hostname) to s3://${bucket}/${fixed_initrd_object} ... "
if ! cray artifacts create "$bucket" "$fixed_initrd_object" /squashfs/initrd.img.xz >"${CURRENT_LOG_DIR}/initrd.upload.log" 2>&1 ; then
    upload_error=1
    echo >&2 'Failed!'
else
    echo 'Done'
fi
if [ "$upload_error" -ne 0 ]; then
    echo >&2 'CrayCLI failed to upload artifacts. Please verify craycli is authenticated, and then re-run this script as "./install-hotfix.sh upload-only" to resume at the failed step.'
    echo >&2 "For insight into the failure, see CrayCLI upload logs at ${CURRENT_LOG_DIR}/{kernel,initrd}.upload.log"
    exit 1
fi

# CSM 1.4 craycli does not support multiple --subrole parameters, we have to go through masters and workers separately.
# Masters.
if IFS=$'\n' read -rd '' -a NCN_XNAMES; then
:
fi <<< "$(cray hsm state components list --role Management --subrole Master --type Node --format json | jq -r '.Components | map(.ID) | join("\n")')"
update-bss "${NCN_XNAMES[@]}"

# Workers.
if IFS=$'\n' read -rd '' -a NCN_XNAMES; then
:
fi <<< "$(cray hsm state components list --role Management --subrole Worker --type Node --format json | jq -r '.Components | map(.ID) | join("\n")')"
update-bss "${NCN_XNAMES[@]}"

echo "The following NCN masters and workers received the patch."
printf "\t%s\n" "${NCNS[@]}"
echo "Each of the listed NCNs must reboot for the patch to take effect."

set +x
cat >&2 <<EOF
+ QLogic driver has been updated. The patch will take affect after the server(s) next reboot.
${0##*/}: OK
EOF
