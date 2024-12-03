#!/usr/bin/env bash
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

set -o errexit
set -o pipefail
set -o xtrace

ROOTDIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")

REPO_LIST=$(cd "${ROOTDIR}/rpm" ; ls | tr '\n' ' ')

function usage {

cat << EOF
usage:

./install-hotfix.sh [--include-rpms | --no-rpms | --rpms-only]

If no flags are specified, the script will prompt the user if they
want the Nexus RPM repositories to be updated with patched
BOS reporter, CMS test, and Cray CLI RPMs.
If so, the script runs as if --include-rpms had been specified.
If not, the script runs as if --no-rpms had been specified.

To run the script noninteractively, specify one of the following
mutually exclusive flags:

--include-rpms  Patch the BOS, CFS, and PCS services.
                Recreate the following Nexus repos to include the updated RPMs:
                $REPO_LIST

--no-rpms       Only patch the BOS, CFS, and PCS services.
                Do not add the updated RPMs to Nexus.

--rpms-only     Do not patch the BOS, CFS, and PCS services.
                (The relevant charts and images will also not be uploaded
                to Nexus)
                Recreate the following Nexus repos to include the updated RPMS:
                $REPO_LIST

EOF
}

# Defaults:
patch_services=Y
patch_rpms=""

if [[ $# -gt 1 ]]; then
    usage
    echo "ERROR: Too many arguments specified" >&2
    exit 2
elif [[ $# -eq 1 ]]; then
    case "$1" in
        "--include-rpms")
            patch_services=Y
            patch_rpms=Y
            ;;
        "--no-rpms")
            patch_services=Y
            patch_rpms=N
            ;;
        "--rpms-only")
            patch_services=N
            patch_rpms=Y
            ;;
        *)
            usage
            echo "ERROR: Unrecognized flag: '$1'" >&2
            exit 2
            ;;
    esac
fi

if [[ -z ${patch_rpms} ]]; then
    cat << EOF
This hotfix includes updated Cray CLI and BOS reporter RPMs. In order to add them to Nexus, the following repos must be destroyed and
recreated to include the additional content: $REPO_LIST

This is irreversible.
EOF
    read -r -p "Include RPM updates in the patch? [y/n]:" response
    case "$response" in
        [yY][eE][sS]|[yY])
            echo "Nexus will be updated to include the patched RPMs"
            patch_rpms=Y
            ;;
        [nN][oO]|[nN])
            echo "Nexus will NOT be updated to include the patched RPMs"
            patch_rpms=N
            ;;
        *)
            echo "Unrecognized response" >&2
            exit 2
            ;;
    esac
fi

source "${ROOTDIR}/lib/version.sh"

if [[ ${patch_services} == Y ]]; then
    # Create scratch space
    workdir="$(mktemp -d)"
    trap "rm -fr '${workdir}'" EXIT

    # Build manifest
    # The PCS and CFS updates include fixes that BOS needs, which is why we do those updates first.
    cat > "${workdir}/manifest.yaml" << EOF
apiVersion: manifests/v1beta1
metadata:
  name: csm-1.5-bos-cfs-scale-hotfix
spec:
  charts:
  - name: cray-power-control
    version: 2.0.11
    namespace: services
    timeout: 20m
  - name: cray-cfs-api
    version: 1.18.15
    namespace: services
  - name: cray-bos
    version: 2.10.28
    namespace: services
    timeout: 10m
EOF

    # Extract customizations.yaml
    kubectl -n loftsman get secret site-init -o jsonpath='{.data.customizations\.yaml}' | base64 -d > "${workdir}/customizations.yaml"

    # manifestgen
    manifestgen -c "${workdir}/customizations.yaml" -i "${workdir}/manifest.yaml" -o "${workdir}/deploy-hotfix.yaml"
fi

# Export these variables for use by the setup-nexus script
export patch_services
export patch_rpms

# Load artifacts into nexus
"${ROOTDIR}/lib/setup-nexus.sh"

if [[ ${patch_services} == Y ]]; then
    # Deploy chart
    loftsman ship --manifest-path "${workdir}/deploy-hotfix.yaml" --charts-path "${ROOTDIR}/helm"
fi

set +x
cat >&2 <<EOF
+ Hotfix installed
${0##*/}: OK
EOF
