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
function usage {
cat << 'EOF'
usage:

Running this without arguments will only target Kubernetes worker non-compute nodes.

-a      Run against ALL non-compute nodes
-k      Run against ALL Kubernetes non-compute nodes (masters + workers)
-s      Run against ALL Storage-CEPH non-compute nodes
-u      Only upload the new initrd from THIS node to S3, and update BSS bootparameters.
EOF
}
upload_initrd_only=0
regex='ncn-w\d{3}'
masters=0
workers=1
storage=0
while getopts ":auks" o; do
    case "${o}" in
        a)
            regex='ncn-\w\d{3}'
            masters=1
            workers=1
            storage=1
            ;;
        k)
            regex='ncn-[mw]\d{3}'
            masters=1
            workers=1
            ;;
        s)
            regex='ncn-s\d{3}'
            storage=1
            ;;
        u)
            upload_initrd_only=1
            ;;
        *)
            usage
            exit 0
            ;;
    esac
done

shift $((OPTIND-1))
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
    readarray -t EXPECTED_NCNS < <(grep -oP "$regex" /etc/hosts | sort -u)
    if [ ${#EXPECTED_NCNS[@]} = 0 ]; then
        echo >&2 "No NCNs found in /etc/hosts! This NCN is not initialized, /etc/hosts should have content."
        exit 1
    fi
fi

export NCNS=()
for ncn in "${EXPECTED_NCNS[@]}"; do
    if ping -c 1 "$ncn" >/dev/null 2>&1 ; then
        NCNS+=( "$ncn" )
    else
        echo >&2 "Failed to ping [$ncn]; skipping hotfix for [$ncn]"
    fi
done
export PDSH_SSH_ARGS_APPEND="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

echo 'Purging old kernel(s) ... '
if ! pdsh -S -b -w "$(printf '%s,' "${NCNS[@]}")" '
sle_version="sle-$(awk -F= '\''/VERSION=/{gsub(/["-]/, "") ; print tolower($NF)}'\'' /etc/os-release)"
if [ "${sle_version}" = "sle-15sp3" ]; then
    echo "No hotfix needed for sle-15sp3. Exiting."
    exit 0
fi
if [ "${sle_version}" != "sle-15sp4" ]; then
    echo >&2 "Wrong hotfix! Detected $sle_version, needed sle-15sp4"
    exit 1
fi
zypper removelock kernel-default
zypper --non-interactive purge-kernels --details
zypper addlock kernel-default
'; then
    echo >&2 'Failed to apply PTF kernel update on one or more nodes!'
    exit 1
fi

set +x
cat >&2 <<EOF
+ Old kernels have been cleaned up.
${0##*/}: OK
EOF
