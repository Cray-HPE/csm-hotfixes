# NCN Boot Order Hotfix/Backport

This hotfix applies the CSM 1.2 boot order tooling to the non-compute nodes.

## Requirements

All dependencies and necessities are included in this directory.

The RPMs and scripts may be installed and run in either:
- PIT : Install or Recovery context
- NCN : Runtime context

Invoke this hotfix from `ncn-m001` if possible, but any other NCN should also work if needed, provided it has passwordless ssh enabled with the other NCNs.

> **`CLARIFICATION:`** The intent of this hotfix is executing in runtime. **This** hotfix must run from a node with passwordless-ssh between all the NCNs. **However**, the scripts and RPMs in this hotfix are runnable on a PIT node. Because the PIT node by default is not configured with passwordless-SSH, this hotfix can be run on the PIT node if and only if the user has done the extra step to configure it. 

## Usage

1. Export your BMC password to the shell environment, and then run `install-hotfix.sh` to apply the hotfix: 

    ```bash
    ncn# export IPMI_PASSWORD=opensesame
    ncn# ./install-hotfix.sh
    ```

The NCNs are now configured, and will have deterministic boot ordering.

The BIOS settings applied to the iLO will take effect **after a cold-boot**. The NCNs will be cold booted during an
installation _and_ during an upgrade. If this hotfix is applied out-of-band, then use either of the following to cold boot the node:
- `export IPMI_PASSWORD=opensesame && ipmitool -I lanplus -U <my_bmc_username> -E -H <ncn-x###-mgmt> power reset`
- `shutdown -h -t 0`

## Triage

If the boot order is out-of-spec following this hotfix _and_ a single reboot of the NCN (a single reboot is needed to ensure all BIOS changes were taken, and no new unknowns appeared on during POST), then please provide the following information to CRAY-HPE in the bug-submission:

- `efibootmgr` output of the afflicted node(s).
- The boot-related BIOS settings of the afflicted node(s).
