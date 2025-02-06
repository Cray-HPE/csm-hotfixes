# CSM 1.5 Kdump

This hotfix should be ran in one of three places depending on the state of the machine:
- During a fresh install, before booting NCNs.
- On a running, installed system before an upgrade.
- On a running, installed system with a rolling reboot of the NCNs

After running this hotfix continue installation as usual.

## JIRA(s)

This hotfix covers the following JIRA(s):

* [CASMTRIAGE-6796](https://jira-pro.it.hpe.com:8443/browse/CASMTRIAGE-6796)
* [CASMTRIAGE-7232](https://jira-pro.it.hpe.com:8443/browse/CASMTRIAGE-7232)
* [CASMTRIAGE-6796](https://jira-pro.it.hpe.com:8443/browse/CASMTRIAGE-7709)

  > **NOTE** Both CASMTRIAGE-6796 and CASMTRIAGE-7709 is specific to the fresh install path. If this hotfix is applied to a running system, both CASMTRIAGE-6796 and CASMTRIAGE-7709 can be disregarded.

## Usage

### Fresh Installs

1. Set `CSM_PATH`, this needs to be the root of the extracted 1.5 tarball.

   > Example: `/var/www/ephemeral/csm-1.5.2`

1. Run the hotfix.

    ```bash
    ./hotfix-fresh-install.sh -c "$CSM_PATH"
    ```

### Runtime

Use these steps before a CSM upgrade or on any CSM 1.5 system.

1. Run the hotfix; patch on-disk bootloaders, and update BSS boot parameters.

    ```bash
    ./hotfix-running-system.sh
    ```

1. Perform a rolling reboot of every NCN.
