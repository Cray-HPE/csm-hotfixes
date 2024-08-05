# CSM 1.4 XFS Mount Options

This hotfix fixes lengthy IMS jobs that occur after upgrading to COS 2.5 that can be attributed to the XFS mount options present on NCN Kubernetes nodes.

The hotfix will

- Munge all XFS mount points defined in `/etc/fstab.metal`with the fixed mount options
- Deploy a new `csm-config` for including a newer `dracut-metal-mdsquash` RPM in image builds that contain the mount options
- Updates cray-product-catalog
- Updates CFS configurations for NCNs
- Builds new NCN images

## JIRAs

This hotfix covers the following JIRAs:

* [MTL-2423](https://jira-pro.it.hpe.com:8443/browse/MTL-2423)

## Usage

This hotfix is two-fold; fix the running NCNs, and rebuild images for  

1. Live patch the non-compute nodes.

    ```bash
    ./install-hotfix.sh
    ```

1. Execute a rolling reboot of the non-compute nodes in order to apply the new XFS mount options.

    Use the documentation in docs-csm for a rolling reboot.

1. After completing the rolling reboot, patch the NCN images.

    ```bash
    ./install-hotfix.sh -b
    ```

At this point, the cray-product-catalog is now updated to use the new csm-config as well as all CSM layers in all CFS configurations.

Administrators can now rebuild images against their desired CFS configuration to pickup the hotfix changes. This must be done before the next node rebuild.
