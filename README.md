# CSM Hotfixes

This repo contains hotfixes which are individually packaged and made available to customers in advance of the CSM release.  Changes are built and uploaded per folder as the .version file in each directory is changed.

The resulting artifact becomes available at `https://storage.googleapis.com/csm-release-public/hotfix/<name>-<version|0.0.1>.tar.gz`

New hotfix folders should be named according to the following format [casmrel ticket]_[thing changed]_hotfix.

#### release.sh <hotfix>

This file is what runs to create the build artifact, a tar file.

## Hotfix file structure

This section explains the structure of each hotfix and how it is used for packaging and deploying the hotfix content.

  - `<hotfix>/.version`: A file containing the hotfix's version. If the version was already found to be built and uploaded to GCP the build script will skip this hotfix's build. If not set `0.0.1` is used
  - `<hotfix>/release.sh`: An optional release.sh per hotfix that can run to do any modifications to the hotfix package before being tarballed
  - `<hotfix>/install.sh`: This file runs at the customer site, presumably in a k8s master NCN to populate the new artifacts in Nexus. It will also contain the orchestration necessary to deploy artifacts or changes to the customer environment.
  - `<hotfix>/README.md`: This file contains the documented procedure for applying the hotfix.
  - `<hotfix>/docker/index.yaml`: An optional docker index.yaml file that'll be used to skopeo sync docker images to the hotfix's release
  - `<hotfix>/helm/index.yaml`: An optional helm index.yaml file that contains a list of helm charts to be added to the hotfix's release
  - `<hotfix>/rpm/index.yaml`: An optional list of rpms packages that will added to the hotfix's release
