# CASMCMS-8609

This procedure covers applying the hotfix for CASMCMS-8609, which
will perform the following:

* Update cray-bos helm chart and bos docker image.


## Setup

1. Copy the tar file to a master node
2. on that master node untar the file
3. cd into the CASMMCS-8609 folder

## Execute the upgrade scripts

This hotfix is applied by applying the following script:

```bash
ncn-m001# ./lib/setup-nexus.sh
ncn-m001# ./upgrade.sh
```

## Validation

### BOS:

Once hot fix is installed the `cray-bos-operator-power-on-*` pod should be running
normally, along with all the other bos pods.  The issue this hotfix addresses can
not be tested directly as it is a race-condition during power on.  However, during
power-on sessions using BOS V2, nodes should no longer give up on the power-on
operation and retry by powering-off before the wait times have elapsed.
