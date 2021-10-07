#!/bin/bash
# Author: Russell Bunch <doomslayer@hpe.com>
# Permalink:
trap "printf >&2 'Metal Install: [ % -20s ]' 'failed'" ERR TERM HUP INT
trap "echo 'See logfile at: /var/log/cloud-init-metal.log'" EXIT
set -e

# Echo that we're the original, but stripped down script.
echo "Running stripped CSM 1.2 install.sh script, $0"
# See the original "install.sh" here: https://raw.githubusercontent.com/Cray-HPE/node-image-build/develop/boxes/ncn-common/files/scripts/metal/install.sh?token=AB3JQE4CBRQKCKMZ5UAKHH3BL4264'

# Load the metal library.
printf 'Metal Install: [ % -20s ]\n' 'loading ...' && . /srv/cray/scripts/metal/metal-lib.sh && printf 'Metal Install: [ % -20s ]\n' 'loading done' && sleep 2

# 2. After detaching bootstrap, setup our bootloader..
bootloader() {
    (
        set -x
        local working_path=/metal/recovery
        update_auxiliary_fstab $working_path
        get_boot_artifacts $working_path
        install_grub2 $working_path
    ) 2>/var/log/cloud-init-metal-bootloader.error
}

# 3. Metal configuration for servers and networks.
hardware() {
    (
        set -x
        setup_uefi_bootorder
#         configure_lldp
#         set_static_fallback
#         enable_amsd
    ) 2>/var/log/cloud-init-metal-hardware.error
}

# MAIN
(
    # 2.
    printf 'Metal Install: [ % -20s ]\n' 'running: fallback' >&2
    [ -n "$METAL_TIME" ] && time bootloader || bootloader

    # 3.
    printf 'Metal Install: [ % -20s ]\n' 'running: hardware' >&2
    [ -n "$METAL_TIME" ] && time hardware || hardware

) >/var/log/cloud-init-metal.log

printf 'Metal Install: [ % -20s ]\n' 'done and complete'
