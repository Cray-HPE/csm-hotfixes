# CSM 1.5.2 Tarball Add DST gpg key

This hotfix is exclusive to the 1.5.2 fresh install.

This hotfix will:
* Add the DST gpg key to 1.5.2 base NCN images

After running this hotfix continue installation as usual.

## JIRA(s)

This hotfix covers the following JIRA(s):

* [CASMTRIAGE-6896](https://jira-pro.it.hpe.com:8443/browse/CASMINST-6896)

## Usage

1. Set `CSM_PATH`, this needs to be the root of the extracted 1.5.0 tarball.

   > Example: `/var/www/ephemeral/csm-1.5.0`

1. Run the hotfix.

    ```bash
    ./install-hotfix.sh -c "$CSM_PATH"
    ```
