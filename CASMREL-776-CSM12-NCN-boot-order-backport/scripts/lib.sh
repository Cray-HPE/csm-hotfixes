#!/bin/bash
# # This file was copied from GitHub.
# Permalink: https://github.com/Cray-HPE/node-image-build/blob/ca52e1976c7fe6dfe73eaa0ea46cd729d81fc32b/boxes/ncn-common/files/scripts/common/lib.sh
# This file exists purely to supply mprint for the 1.2 backport - this just keeps behavior the same for the backport and 1.2 release.
function mprint {
    printf '[% -25s] %s\n' "$0" "$1"
}
