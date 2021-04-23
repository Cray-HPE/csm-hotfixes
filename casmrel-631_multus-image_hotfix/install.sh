#!/usr/bin/env bash
set -ex
set -o pipefail

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")"

. ${ROOTDIR}/lib/install.sh

skopeo-sync "${ROOTDIR}/docker"
