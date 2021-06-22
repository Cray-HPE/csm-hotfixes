# CSM Hotfixes

This repo contains hotfixes which are individually packaged and made available
to customers. Changes are built and uploaded per folder as the .version file in
each directory is changed.

The resulting artifact becomes available at
`https://storage.googleapis.com/csm-release-public/hotfix/<name>-<version|0.0.1>.tar.gz`


## Hotfix Distributions

Run `./release.sh <hotfix>` to generate a distribution for the specified
hotfix.


## Hotfix Directory Structure

Each hotfix directory is expected to contain asset indexes and scripts for
applying the hotfix. The following files are used by `release.sh` to generate
hotfix distributions:


  - `.version`: A file containing the hotfix's version. If the version
    was already found to be built and uploaded to GCP the build script will
    skip this hotfix's build. If not set `0.0.1` is used
  - `docker/index.yaml`: An optional docker index.yaml file that'll be
    used to skopeo sync docker images to the hotfix's release
  - `docker/transform.sh`: An optional script to fixup container image
    repositories
  - `helm/index.yaml`: An optional helm index.yaml file that contains
    a list of helm charts to be added to the hotfix's release
  - `lib/version.sh`: Script automatically generated and added to distributions
    by `release.sh`.

Conventions:

  - `README.md`: Hotfix documentation, specifically how to apply it.
  - `lib/setup-nexus.sh`: Script to update Nexus repositories.
  - `lib/install.sh`: Typically a symlink to the `lib/install.sh` library from
    the vendored SHASTARELM/release repo which is used by `lib/setup-nexus.sh`.
  - `install.sh` or `upgrade.sh`: Primary script for applying the hotfix.
    Generally assumes that `lib/setup-nexus.sh` has already been run.
