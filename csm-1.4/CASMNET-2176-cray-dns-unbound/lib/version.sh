#!/usr/bin/env bash

# Copyright 2020 Hewlett Packard Enterprise Development LP

: "${RELEASE:="${RELEASE_NAME:="csm-1.4.3-cray-dns-unbound-CASMNET-2176"}-${RELEASE_VERSION:="1.0.0"}"}"

# return if sourced
return 0 2>/dev/null

# otherwise print release information
if [[ $# -eq 0 ]]; then
    echo "$RELEASE"
else
    case "$1" in
    -n|--name) echo "$RELEASE_NAME" ;;
    -v|--version) echo "$RELEASE_VERSION" ;;
    *)
        echo >&2 "error: unsupported argumented: $1"
        echo >&2 "usage: ${0##*/} [--name|--version]"
        ;;
    esac
fi
