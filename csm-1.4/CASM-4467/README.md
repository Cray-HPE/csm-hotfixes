# CASM-4467: iuf-container is using a buggy version of cray-cli

## Problem Description

In CSM 1.4.1, there is a critical bug in IUF which prevents certain parts of `deliver-product` stage to work, resulting in a failed `deploy-product` stage.

**You only need to apply this workaround if you are on CSM 1.4.1.** All CSM versions from 1.4.2 onwards have this fix already.

## How to install

To apply the workaround:

1. Run the contained script `install-hotfix.sh`.
2. Install the latest documentation RPM. See [docs-csm](https://cray-hpe.github.io/docs-csm/en-14/update_product_stream/readme/#check-for-latest-documentation) for instructions on how to do so.
3. Run the newly updated script from docs-csm located in `/usr/share/doc/csm/workflows/scripts/upload-rebuild-templates.sh`