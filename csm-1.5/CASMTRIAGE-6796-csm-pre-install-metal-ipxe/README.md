# CSM 1.5.0 Tarball Noos Repository

This hotfix is exclusive to the 1.5.0 fresh install. It is imperative to run this hotfix immediately following the extraction
of the CSM tarball on the PIT. Specifically, after step 3 of section 2 in the [pre-installation](https://github.com/Cray-HPE/docs-csm/blob/release/1.5/install/pre-installation.md#2-download-and-extract-the-csm-tarball).

This hotfix will:
* Copy a new `metal-ipxe` package into an extracted CSM tarball.
* Recreate/update the repodata in the extracted tarball.

After running this hotfix continue installation as usual.

## JIRA(s)

This hotfix covers the following JIRA(s):

> ***NOTE*** If/when additional RPMs are added, their corresponding JIRAs should be included here.

* [CASMTRIAGE-6796](https://jira-pro.it.hpe.com:8443/browse/CASMTRIAGE-6796)

## Usage

1. Set `CSM_PATH`, this needs to be the root of the extracted 1.5.0 tarball.

   > Example: `/var/www/ephemeral/csm-1.5.0`

1. Run the hotfix.

    ```bash
    ./install-hotfix.sh -c "$CSM_PATH"
    ```
