# CASMHMS-5236

This procedure covers applying the hotfix for CASMHMS-5220, which
will perform the following:

* Update cray-scsd helm chart and SCSD docker image.


## Setup

1. Copy the tar file to a master node
2. on that master node untar the file
3. cd into the CASMHMS-5236-1.4.2-1 folder

## Execute the upgrade scripts

This hotfix is applied by applying the following script:

```bash
ncn-m001# ./lib/setup-nexus.sh
ncn-m001# ./upgrade.sh
```

## Validation

### SCSD:

Once hot fix is installed the SCSD pod can be verified by using it to
modify the BMC credentials on an iLO BMC.  In the steps below, the BMC
named 'x1000c0s0b0' will be used -- substitue this for an actual iLO
BMC.

1. Create a creds JSON file, (example: "creds.json") e.g.:

```
{
  "Username": "root",
  "Password": "<REDACTED>",
  "Targets": [ "x1000c0s0b0"]
}
  
```

Obviously, use a reasonable password.

2. Use the CLI to set the password:

```
# cray scsd bmc globalcreds create creds.json
```

This should complete with no errors, and the output should show a favorable
status code for the target.


3. Do a curl command to access protected Redfish content on target BMC:

```
# NOTE: substitute 'XXX' below with the password specified in creds.json

# curl -s -k -u root:XXX https://x1000c0s0b0/redfish/v1/Systems
```

This should succeed.

4. Change the password back to the original password, and verify, using steps 1-3 above.


NOTICE

This hotfix will need to be re-applied after installing an versions between 
csm-0.9.4 to csm-1.0.  This hotfix does not need to be re-applied when installing 
csm-1.0.1 or newer.

