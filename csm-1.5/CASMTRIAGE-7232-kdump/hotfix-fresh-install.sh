#!/bin/bash
#
# MIT License
#
# (C) Copyright 2024 Hewlett Packard Enterprise Development LP
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
ROOT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "${ROOT_DIR}/lib/install.sh"
source "${ROOT_DIR}/lib/version.sh"

function usage {

  cat << EOF
usage:

./install-hotfix.sh [-v] [-c CSM_PATH]

Flags:

-c              Set the CSM_PATH with a value via the command-line.
-v              Verbose (run with set -x).

Environment Variables:
CSM_PATH        The root of the extracted CSM tarball.
EOF
}

CSM_PATH="${CSM_PATH:-}"
while getopts ":vc:" o; do
  case "${o}" in
    c)
      CSM_PATH="${OPTARG}"
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
if [ -z "$CSM_PATH" ]; then
  echo >&2 "CSM_PATH was not set! Aborting."
  exit 1
fi

if ! load-install-deps; then
  echo >&2 'Failed to load installation deps! Hotfix is corrupt.'
  exit 1
fi
echo "Installing fresh install hotfix: $RELEASE_NAME-$RELEASE_VERSION"

repository="${CSM_PATH}/rpm/cray/csm/noos"
if [ ! -d "$repository" ]; then
  echo >&2 "$repository was not found! Directory does not exist. Tarball needs to be downloaded and extracted before running this hotfix."
  exit 1
fi
printf 'Copying hotfix RPMs into downloaded repository %s ... ' "$repository"
if rsync -rltDq "${ROOT_DIR}/rpm/" "${repository}/"; then
  echo 'Done'
else
  echo 'Failed!'
  exit 1
fi

echo "Updating repodata for $repository ... "
createrepo "$repository"

boot_script="$(rpm -q --filesbypkg metal-ipxe | awk '/script\.ipxe/{print $NF}')"
if [ -z "$boot_script" ]; then
  # No old boot script to remove, metal-ipxe is not installed.
  :
elif [ -f "$boot_script" ]; then
  # Remove the old boot script to prevent `metal-ipxe` from installing its new script as `script.ipxe.rpmnew`
  rm -f "$boot_script"
fi

echo "Cleaning up ... "
clean-install-deps

cat >&2 << EOF
+ Hotfix installed
${0##*/}: OK
EOF
