#!/usr/bin/env bash

if [[ $# -ne 2 ]]; then
    echo >&2 "usage: ${0##*/} SCRIPT VERSION"
    exit 1
fi

script="$1"
version="$2"

if [[ ! -f "$script" ]]; then
    echo >&2 "error: no such file: $script"
    exit 2
fi

source "$script"

ROOTDIR="$(dirname "${BASH_SOURCE[0]}")"
source "${ROOTDIR}/vendor/github.hpe.com/hpe/hpc-shastarelm-release/lib/release.sh"

gen-version-sh "$RELEASE_NAME" "$version" > "$script"
chmod +x "$script"

git add "$script"
git --no-pager diff --staged
