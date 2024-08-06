# CSM 1.4 HPE GPG Keys

This hotfix imports a new HPE GPG key for newer product packages into an environment running 1.4.0, 1.4.1, 1.4.2, 1.4.3, or 1.4.4.

- Import the GPG key into the running NCNs
- Updates the Kubernetes hpe-signing-keys secret with the new key
- Deploys a new `csm-config` for baking the key into NCN image builds and to ensure the key is imported during node personalization as an extra precaution
- Updates cray-product-catalog
- Updates CFS configurations for NCNs
- Builds new NCN images with the new GPG key baked in

## JIRA

This hotfix covers the following JIRA:

* [CASMINST-6896](https://jira-pro.it.hpe.com:8443/browse/CASMTRIAGE-6896)

## Usage

Run the script to import the new key into the running NCNs and build new NCN images. The resulting images can be used for adding or rebuilding NCNs operations.

```bash
./install-hotfix.sh
```

### Keys Only

Run the script with `-k` to skip all CFS work and only import the keys into running NCNs.

```bash
./install-hotfix.sh -k
```

At this point, the cray-product-catalog is now updated to use the new csm-config as well as all CSM layers in all CFS configurations.

Administrators can now rebuild images against their desired CFS configuration to pickup the hotfix changes. This must be done before the next node rebuild.