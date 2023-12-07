# QLogic Hotfix (15-SP4)

* [Setup](#setup)
* [Execute the Hotfix](#execute-the-hotfix)
* [Logs](#logs)
    * [Restoring BSS Bootparameters](#restoring-bss-bootparameters)
* [Installing Debug Symbols](#installing-debug-symbols)

This procedure covers applying the hotfix for the QLogic kernel panics pertaining to:

- Marvell 2P 25GbE SFP28 QL41232HQCU-HC OCP3 Adapter
- Marvell FastLinQ 41000 Series - 2P 25GbE SFP28 QL41232HLCU-HC MD2 Adapter

> ***NOTE*** This hotfix will skip nodes that do NOT run SLE-15-SP4, for example in CSM 1.4.X storage NCNs will be skipped
> as these run SLE-15-SP3.

The hotfix includes:

- Applying new kernel module options to the `qede` module
- Installing a PTF Kernel from SUSE and Marvell
- **Removing** the previous Kernel packages (this can not be undone)
- Installing an updated set of kernel modules for the QLogic Fastlinq MD2/OCP cards
- Updating the initrd on the local disk bootloader and in S3, as well as adjusting BSS to use the new set of artifacts

> ***NOTE*** This patch can not be rolled back. If a rollback of the node(s) targeted by this patch is desired, their
> BSS boot parameters need to be restored, and the node needs to be rebuilt.
> Backups of the original BSS boot parameters will exist in `/var/log/qlogic-hotfix/<date>/`. See [restoring BSS bootparameters](#restoring-bss-bootparameters).

## Setup

1. Copy the tar to a master node.
2. On that master node `untar` the tar and change into the hotfix folder

   ```bash
   cd csm-qlogic-hotfix-sle-15sp4-*
   ```

## Execute the hotfix

This hotfix is applied by applying the following script, run `-h` to view the NCN selection options:

```bash
./install-hotfix.sh -h
```

Re-run the script with no arguments for the default NCN selection, or with one of the printed choices.
After the script exits successfully, each node the script listed will need to reboot for the patch to take effect.

Please reboot these at your leisure.

## Logs

The script generates log files on the node that it was invoked on.

See `/var/log/qlogic-hotfix/<date>/` for:

- `kernel.upload.log` : Output from uploading the kernel to S3
- `initrd.upload.log` : Output from uploading the new initrd to S3
- `patch.xtrace` : Debug output (`set -x`) from the script
- `$NCN_XNAME.bss.backup.json` : The BSS boot parameters from before the script modified them.

### Restoring BSS bootparameters.

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

## Installing Debug Symbols

This hotfix includes the `kernel-default-debuginfo` package in its Nexus repository.

The debug symbols for the new Kernel version can be installed on the running node by calling the`install-debuginfo.sh`
script.

Otherwise, the RPM itself is located in this extracted tar ball in `rpm/x86_64/` for local installs.
