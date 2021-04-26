#!/usr/bin/env bash
set -ex
set -o pipefail

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")"

. ${ROOTDIR}/lib/install.sh

load-install-deps

skopeo-sync "${ROOTDIR}/docker"
