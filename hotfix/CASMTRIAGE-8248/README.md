# CASMTRIAGE-8248: Enable signatures along with docker image in skopeo sync
## Problem Description

In CSM 1.6.x, IUF uses skopeo to upload docker images to the nexus repository.  When CSM add on products are installed with iuf, errors are reported in the `deliver-product` stage when signed images are uploaded.

**You only need to apply this workaround if you are on CSM 1.6.x.** All CSM versions from 1.7.0 onwards have this fix already.

## How to install

To apply the workaround:

1. Run the contained script `install-hotfix.sh`.
2. Install the latest documentation RPM. See [docs-csm](https://cray-hpe.github.io/docs-csm/en-16/update_product_stream/#check-for-latest-documentation) for instructions on how to do so.
3. Run the newly updated script from docs-csm located in `/usr/share/doc/csm/workflows/scripts/upload-rebuild-templates.sh`