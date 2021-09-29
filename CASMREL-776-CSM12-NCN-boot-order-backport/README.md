# NCN Boot Order Hot-fix/Backport

This hot-fix applies the CSM 1.2 boot order tooling to the non-compute nodes.

## Requirments

All dependencies and necessities are included in this directory.

The RPMs and scripts may be installed and run in either:
- PIT : Install or Recovery context
- NCN : Runtime context

Ideally, invoke this hot-fix from ncn-m001 (e.g. any NCN that is reachable over SSH).

> **`CLARIFICATION:`** The intent of this hotfix is executing in runtime, **this** hotfix must run from a node with passwordless-ssh between all the NCNs. **However**, the scripts and RPMs in this hotfix are runnable on a PIT node. The PIT node by default is not configured with passwordless-SSH, the PIT can run this hotfix if and only if the user done the extra step to configure it. This is valuable information for recovery and re-deploy contexts such as; customer wants to use this on a fresh install, or has a problem during an upgrade.

## Usage

1. Export your BMC password to the shell environment, and then run `install-hotfix.sh` to apply the hot-fix: 

    ```bash
    ncn# export IPMI_PASSWORD=opensesame
    ncn# ./install-hotfix.sh
    ```

The NCNs are now configured, and will have deterministic boot ordering.

The BIOS settings applied to the iLO will take effect **after a cold-boot**. The NCNs will be cold-booted during an
installation _and_ during an upgrade. If this hot-fix is applied out-of-band, then use either of the following to cold-boot the node:
- `export IPMI_PASSWORD=opensesame && ipmitool -I lanplus -U $username -E -H $node power reset`
- `shutdown -h -t 0`

## Triage

If the boot order is out-of-spec following this hot-fix _and_ a single reboot of the NCN (a single reboot is needed to ensure all BIOS changes were taken, and no new unknowns appeared on during POST), then plaese provide the following information to CRAY-HPE in the bug-submission:

- `efibootmgr` output of the afflicted node(s)
- `node=ncn-m002 && ilorest login $node -u $(whoami) -p $IPMI_PASSWORD && ilorest --nologo list --selector=BIOS.` dump the BIOS settings of the afflicted node(s)
