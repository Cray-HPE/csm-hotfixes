# CSM 1.4 HPE GPG Keys

This hotfix imports a new HPE GPG key for newer product packages into an environment running 1.4.0, 1.4.1, 1.4.2, 1.4.3, 1.4.4

- Import the GPG key into the running NCNs
- Updates the Kubernetes hpe-signing-keys secret with the new key
- Deploys a new `csm-config` for baking the key into NCN image builds and to ensure the key is imported during node personalization as an extra precaution
- Updates cray-product-catalog
- Updates CFS configurations for NCN's
- Builds new NCN images with the new GPG key baked in

## JIRA(s)

This hotfix covers the following JIRA(s):

* [CASMINST-6896](https://jira-pro.it.hpe.com:8443/browse/CASMTRIAGE-6896)

## Usage

Run the script to import the new key into the running NCNs and build a new NCN image for adding or rebuilding NCNs operations.

```bash
./install-hotfix.sh
```

### Keys Only

Run the script with `-k` to skip all CFS work and only import the keys into running NCNs.

```bash
./install-hotfix.sh -k
```
