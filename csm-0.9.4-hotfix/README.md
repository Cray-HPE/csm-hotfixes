# CSM 0.9.4 Hotfix Distribution

Download the latest docs-csm RPM and follow the procedures for upgrading to CSM
0.9.4 which will guide you through running `lib/setup-nexus.sh` to update Nexus
repositories and `upgrade.sh` to upgrade system management services.

1. Download and install/upgrade the workaround and documentation RPMs. If this machine does not have direct internet access these RPMs will need to be externally downloaded and then copied to be installed.
- ncn-m001# rpm -Uvh https://storage.googleapis.com/csm-release-public/shasta-1.4/docs-csm-install/docs-csm-install-latest.noarch.rpm
- ncn-m001# rpm -Uvh https://storage.googleapis.com/csm-release-public/shasta-1.4/csm-install-workarounds/csm-install-workarounds-latest.noarch.rpm
