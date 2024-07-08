# CSM 1.5 HPE GPG Keys

This hotfix imports a new HPE GPG key for newer product packages into an environment running 1.5.0, 1.5.1, or a 1.5.2 pre-release.

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

Run the script to import the new key into the running NCNs and build a new NCN image for adding or rebuilding NCNs operations.

```bash
./install-hotfix.sh
```

### Keys Only

Run the script with `-k` to skip all CFS work and only import the keys into running NCNs.

```bash
./install-hotfix.sh -k
```
