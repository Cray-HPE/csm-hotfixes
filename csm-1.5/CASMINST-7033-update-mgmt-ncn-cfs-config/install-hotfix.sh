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
set -eo pipefail
ROOT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "${ROOT_DIR}/lib/install.sh"
source "${ROOT_DIR}/lib/version.sh"

function usage {

  cat << EOF
usage:

./install-hotfix.sh [-v] [-c CSM_DISTDIR]

Flags:

-c              The location of the extracted CSM release distribution
-v              Enable verbose output (run with set -x).

Environment Variables:
CSM_DISTDIR        The root of the extracted CSM release distribution
EOF
}

CSM_DISTDIR="${CSM_DISTDIR:-}"
while getopts ":vc:" o; do
  case "${o}" in
    c)
      CSM_DISTDIR="${OPTARG}"
      ;;
    v)
      set -x
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done
shift $((OPTIND - 1))

if [ -z "$CSM_DISTDIR" ]; then
    echo >&2 "CSM_DISTDIR was not set! Aborting."
    exit 1
fi

CFS_CONFIG_UTIL_REL_PATH="vendor/cfs-config-util.tar"
NEW_CFS_CONFIG_UTIL_PATH="${ROOT_DIR}/${CFS_CONFIG_UTIL_REL_PATH}"
OLD_CFS_CONFIG_UTIL_PATH="${CSM_DISTDIR}/${CFS_CONFIG_UTIL_REL_PATH}"

echo "Backing up ${OLD_CFS_CONFIG_UTIL_PATH} to ${OLD_CFS_CONFIG_UTIL_PATH}.old"
mv "${OLD_CFS_CONFIG_UTIL_PATH}" "${OLD_CFS_CONFIG_UTIL_PATH}.old"

echo "Copying fixed cfs-config-util image from ${NEW_CFS_CONFIG_UTIL_PATH} to ${OLD_CFS_CONFIG_UTIL_PATH}"
cp "${NEW_CFS_CONFIG_UTIL_PATH}" "${OLD_CFS_CONFIG_UTIL_PATH}"

cat >&2 <<EOF
+ Hotfix installed
${0##*/}: OK
EOF
