#!/usr/bin/env bash
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

set -o errexit
set -o pipefail
set -o xtrace

ROOTDIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")

REPO_LIST=$(cd "${ROOTDIR}/rpm" ; ls | tr '\n' ' ')

function usage {

cat << EOF
usage:

./install-hotfix.sh

EOF
}

patch_rpms=Y
patch_services=N

source "${ROOTDIR}/lib/version.sh"

# Export these variables for use by the setup-nexus script
export patch_services
export patch_rpms

# Load artifacts into nexus
"${ROOTDIR}/lib/setup-nexus.sh"

set +x
cat >&2 <<EOF
+ Hotfix installed
${0##*/}: OK
EOF
