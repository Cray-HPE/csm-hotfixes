# CASMTRIAGE-5033

This procedure covers applying the hotfix for the QLogic kernel panics pertaining to:

- Marvell 2P 25GbE SFP28 QL41232HQCU-HC OCP3 Adapter
- Marvell FastLinQ 41000 Series - 2P 25GbE SFP28 QL41232HLCU-HC MD2 Adapter

## Prerequisites

## Setup

1. Copy the tar to a master node.
2. On that master node `untar` the tar and change into the CASMTIRAGE-5033 folder

   ```bash
   cd csm-1.4.1-qlogic-hotfix-1
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
