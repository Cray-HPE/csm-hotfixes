#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP

set -o errexit
set -o pipefail

WORKING_DIR=$(dirname $0)
source "${WORKING_DIR}/lib/version.sh"
source "${WORKING_DIR}/scripts/download.sh"

# Installs RPMs, or fetches them if possible.
function install_rpms {
    local ilorest=0
    local pit_init=0
    rpm -Uvh ${WORKING_DIR}/rpm/pit-init-$PIT_VER.noarch.rpm || pit_init=1
    rpm -Uvh ${WORKING_DIR}/rpm/ilorest-$ILO_VER.x86_64.rpm || ilorest=1
    if [ $ilorest = 1 ] || [ $pitinit = 1] ; then
        rm -f ${WORKING_DIR}/rpm/pit-init-$PIT_VER.noarch.rpm
        rm -f ${WORKING_DIR}/rpm/ilorest-$ILO_VER.x86_64.rpm
        getdeps # sourced from download.sh
    fi
}

# Copies files into place.
function copy {
    if [ -f /etc/pit-release ]; then
        read -r -p "this requires passwordless-SSH; please run this on an NCN or configure the PIT with passwordless-SSH otherwise password prompts will occur. Continue? [y/n]: " response
        case "$response" in
            [yY][eE][sS]|[yY])
                :
                ;;
            *)
                echo 'exiting ...'
                exit 1
                ;;
        esac
    fi
    echo "Copying ${WORKING_DIR}/mini-install.sh and ${WORKING_DIR}/metal-lib.sh ${WORKING_DIR}/lib.sh to ..."
    for ncn in $(grep -oP 'ncn-\w\d+' /etc/hosts | sort -u); do
        echo "$ncn:/srv/cray/scripts/metal/mini-install.sh"
        scp ${WORKING_DIR}/scripts/mini-install.sh ${ncn}:/srv/cray/scripts/metal/ >/dev/null
        echo "$ncn:/srv/cray/scripts/metal/metal-lib.sh"
        scp ${WORKING_DIR}/scripts/metal-lib.sh ${ncn}:/srv/cray/scripts/metal/ >/dev/null
        echo "$ncn:/srv/cray/scripts/common/lib.sh"
        scp ${WORKING_DIR}/scripts/lib.sh ${ncn}:/srv/cray/scripts/common/ >/dev/null
    done

}

# Runs the scripts
function run {
    if [ -z "$IPMI_PASSWORD" ] ; then
        echo >&2 'Need IPMI_PASSWORD exported to the environment.'
    fi
    echo 'Adjusting BIOS facilitating network booting ... (/root/bin/bios-baseline.sh)'
    export CI='yes' && /root/bin/bios-baseline.sh
    unset CI
    echo 'Adjusting UEFI Boot Order ... '
    for ncn in $(grep -oP 'ncn-\w\d+' /etc/hosts | sort -u); do
        echo "$ncn - starting mini-install.sh"
        ssh -o StrictHostKeyChecking=no $ncn /srv/cray/scripts/metal/mini-install.sh
        echo "$ncn - done"
    done
}

function main {
    # Load artifacts into nexus
   # ${WORKING_DIR}/lib/setup-nexus.sh
    rpm -q ilorest pit-init || install_rpms
    copy
    run
    echo 'Done'
}

main