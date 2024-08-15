# CASMTRIAGE-5033

This procedure covers applying the hotfix for the QLogic kernel panics pertaining to:

- Marvell 2P 25GbE SFP28 QL41232HQCU-HC OCP3 Adapter
- Marvell FastLinQ 41000 Series - 2P 25GbE SFP28 QL41232HLCU-HC MD2 Adapter

## What's included

This hotfix strictly only backports the Marvell/QLogic Kernel driver from CSM V1.4.4 into earlier 1.4 releases.

The complete fix for the Marvell/QLogic Kernel panic included other pieces that are not covered by this hotfix.

However, the driver resolves the root cause of Kernel panics, a fault in the QLogic kernel driver's recovery mode that prevents a successful recovery of a network interface.

The driver will address issues returning network devices to normal operations after an invalid exception occurs triggering the driver recovery flow.

### What is not included

The rest of the fix resolved issues that cascade from the crashing driver:

- Blacklisting the QLogic RDMA kernel module `qedr` to remove an extraneous ingress in `/etc/dracut.conf.d/99-csm-ansible.conf`; a recommendation by Marvell
    - Removal of `/etc/dracut.conf.d/fastlinq.conf` installed by the new driver, this forces the `qedr` module to load. 
- Installing the `5.14.21-150400.24.100.2.27359.1.PTF.1215587` Kernel from SuSE; this removes an edge case that can occur when the QLogic driver crashes
    - Updating `/etc/zypp/zypp.conf:multiversion.kernels` to match the new kernel version

The changes listed above are included in CSM 1.4.4 and higher.  

## Prerequisites

## Setup

1. Copy the tar to a master node.
2. On that master node `untar` the tar and change into the CASMTIRAGE-5033 folder

   ```bash
   cd csm-1.4.1-qlogic-hotfix-4
   ```

## Execute the hotfix

This hotfix is applied by applying the following script:

```bash
./install-hotfix.sh
```

After the script exits successfully, each node the script listed will need to reboot for the patch to take effect.

Please reboot these at your leisure.

## Logs

The script generates log files on the node that it was invoked on.

See `/var/log/qlogic-hotfix/<date>/` for:

- `kernel.upload.log` : Output from uploading the kernel to S3
- `initrd.upload.log` : Output from uploading the new initrd to S3
- `patch.xtrace` : Debug output (`set -x`) from the script
- `$NCN_XNAME.bss.backup.json` : The BSS boot parameters from before the script modified them.

### Restoring BSS boot parameters.


1. Change into a desired `/var/log/qlogic-hotfix/<data>` directory.
1. Run the following:

    ```bash
    export XNAME="<desired node's xname>"
    export TOKEN=$(curl -k -s -S -d grant_type=client_credentials \
      -d client_id=admin-client \
      -d client_secret=`kubectl get secrets admin-client-auth -o jsonpath='{.data.client-secret}' | base64 -d` \
      https://api-gw-service-nmn.local/keycloak/realms/shasta/protocol/openid-connect/token | jq -r '.access_token')
    curl -i -k -H "Authorization: Bearer ${TOKEN}" -X PUT \
        https://api-gw-service-nmn.local/apis/bss/boot/v1/bootparameters \
        --data @./$XNAME.bss.backup.json
    ```
