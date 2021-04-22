# CSM Hotfixes

This repo contains hotfixes which are individually packaged and made available to customers in advance of the CSM release.  Changes are built and uploaded per folder as the .version file in each directory is changed.

The resulting artifact becomes available at [insert GCP URL].

New hotfix folders should be named according to the following format [casmrel ticket]_[thing changed]_hotfix.

## Hotfix folder/file structure

This section explains the structure of each hotfix and how it is used for packaging and deploying the hotfix content.


#### manifests/

This folder contains separate manifests for the container images, helm charts, and RPMs required in the hotfix.


#### build.sh

This file is what runs to create the build artifact, a tar file.


#### release.sh

This file runs at the customer site, presumably in a k8s master NCN to populate the new artifacts in Nexus.


#### install.sh

This file contains the orchestration necessary to deploy artifacts or changes to the customer environment.


#### README.md

This file contains the documented procedure for applying the hotfix.



