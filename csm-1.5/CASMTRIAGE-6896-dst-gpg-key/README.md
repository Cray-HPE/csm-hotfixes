# CSM 1.5.2 Tarball Add DST gpg key

This hotfix is exclusive to CSM upgrades to 1.5.2

This hotfix will:
* Add the DST gpg key to all running NCN's
* Add the DST gpg key to all currently booted images in IMS
* Add the DST gpg key to 1.5.2 base NCN images

After running this hotfix continue installation as usual.

## JIRA(s)

This hotfix covers the following JIRA(s):

* [CASMTRIAGE-6896](https://jira-pro.it.hpe.com:8443/browse/CASMINST-6896)

## Usage

1. Run the hotfix.

    ```bash
    ./install-hotfix.sh -c "$CSM_PATH"
    ```
