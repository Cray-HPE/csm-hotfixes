This will update FAS from version 1.24.0 to version 1.24.1

Version 1.24.0 contains an issue with the semver pyhton library that was included
with that release which causes the loader to fail.
Version 1.24.1 is created with the old version of the semver python library.

**NOTE**: If you are on an airgap machine, you will need to down the FAS v1.24.1 tar file and move it to the machine in the same directory as this install script.

Example to download FAS v1.24.1 tar file (Use podman instead of docker if needed):

```bash
docker pull us-docker.pkg.dev/csm-release/csm-docker/stable/cray-firmware-action:1.24.1
docker save us-docker.pkg.dev/csm-release/csm-docker/stable/cray-firmware-action:1.24.1 > fas-1.24.1.tar
```

**NOTE**: If you need to have a proxy to have access to external sites, it needs to be set.
You may need to unset proxy after running script.

Example of proxy settings:

```bash
export https_proxy=http://hpeproxy.its.hpecorp.net:443
export no_proxy=.local
```

Run `install.sh` in this directory to install version 1.24.1 of FAS.
**NOTE**: The `cray cli` must be installed and configured for the script to work.

Once the script completes, check the output and check the version of FAS

Wait for new FAS pod to start running:
`kubectl -n services get pods | grep fas`

Check version of FAS (should be 1.24.1)
`cray fas service version list`
