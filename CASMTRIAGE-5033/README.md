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
