# CASMINST-7033: CFS configuration data loss when running `update-mgmt-ncn-cfs-config.sh`

## Affected CSM versions

This hotfix addresses a problem that occurs only during the following scenarios:

* Upgrade of a CSM 1.5.0 system to CSM 1.5.1 or 1.5.2
* Upgrade of a CSM 1.5.1 system to CSM 1.5.2

Note that even if the hotfix has already been applied during an upgrade from CSM 1.5.0 to 1.5.1, it
is still required when upgrading from CSM 1.5.1 to 1.5.2. This is because it affects a script
included in the CSM 1.5.1 and 1.5.2 release distributions.

This hotfix does not apply to fresh installs of CSM 1.5.1 or 1.5.2, and it does not apply for
upgrades from CSM 1.4.z to CSM 1.5.z. Those procedures use different instructions, which are not
affected by this problem. However, no problems will occur if this hotfix is applied in those
situations.

## Problem description

The instructions for installing the CSM 1.5.1 and 1.5.2 patches include a step that runs the script
`update-mgmt-ncn-cfs-config.sh`. This script finds the CFS configuration applied to the management
nodes and updates the CSM layers of that configuration to include the latest content from the CSM
patch. If the CFS configuration contains the `additional_inventory` property or if any layers
contain the `special_parameters.ims_require_dkms` property, that information is lost in the modified
configuration.

See the following JIRAs for more information:

* [CASMINST-7033](https://jira-pro.it.hpe.com:8443/browse/CASMINST-7033)
* [CAST-36034](https://jira-pro.it.hpe.com:8443/browse/CAST-36034)
* [CRAYSAT-1840](https://jira-pro.it.hpe.com:8443/browse/CRAYSAT-1840)
* [CRAYSAT-1842](https://jira-pro.it.hpe.com:8443/browse/CRAYSAT-1842)
* [CRAYSAT-1862](https://jira-pro.it.hpe.com:8443/browse/CRAYSAT-1862)

## Hotfix details

This hotfix will replace the version of the `cfs-config-util` Docker image with a fixed version.
This Docker image is used by the `update-mgmt-ncn-cfs-config.sh` script.

## Installation instructions

This hotfix should be installed during the process of upgrading from a CSM 1.5 release to CSM
1.5.1 or 1.5.2. Specifically, it must be installed prior to running the procedure in [Update
management node CFS configuration](https://github.com/Cray-HPE/docs-csm/blob/release/1.5/upgrade/1.5.2/README.md#update-management-node-cfs-configuration).

1. (`ncn-m001`) Set `CSM_DISTDIR` to be the root of the extracted CSM 1.5.1 or 1.5.2 release
   distribution tar file. For example:

   ```
   export CSM_DISTDIR="/etc/cray/upgrade/csm/csm-1.5.2"
   ```

1. (`ncn-m001`) Execute `install-hotfix.sh` to install the hotfix into the extracted CSM 1.5.1 or
   1.5.2 release:

    ```bash
    ./install-hotfix.sh -c "$CSM_DISTDIR"
    ```

1. Return to the patch installation instructions for the patch being installed:
   
   * CSM 1.5.1: [Update management node CFS configuration](https://github.com/Cray-HPE/docs-csm/blob/release/1.5/upgrade/1.5.1/README.md#update-management-node-cfs-configuration)
   * CSM 1.5.2: [Update management node CFS configuration](https://github.com/Cray-HPE/docs-csm/blob/release/1.5/upgrade/1.5.2/README.md#update-management-node-cfs-configuration)

