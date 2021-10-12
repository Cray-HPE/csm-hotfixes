#!/bin/bash
# # This file was copied from GitHub.
# Permalink:
# This file exists purely to supply mprint for the 1.2 backport - this just keeps behavior the same for the backport and 1.2 release.
function mprint {
    printf '[% -25s] %s\n' "$0" "$1"
}
