#!/bin/bash
# # This file was copied from GitHub.
# permalink: https://github.com/Cray-HPE/node-image-build/blob/a260905eb451d2bbf1a098d2f1f5cbde08d89b4c/boxes/ncn-common/files/scripts/common/lib.sh
# This file exists purely to supply mprint for the 1.2 backport - this just keeps behavior the same for the backport and 1.2 release.
function mprint {
    printf '[% -25s] %s\n' "$0" "$1"
}
