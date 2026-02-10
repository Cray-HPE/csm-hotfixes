# CSM 1.7.0 NOOS Repository

Updates the `csm-noos` repository with any RPMs that missed the CSM V1.7.0 official tarball.

This hotfix will:
* Resolve the repository associated with your CSM 1.7.0 release (e.g. csm-1.7.0-noos)
* Download all of the artifacts in the remote active repository.
* Collate this hotfix's RPMs into the downloaded repository.
* Updates metadata in the collated, local repository.
    * Installs `createrepo_c` if it is not already installed.
* **Delete** the remote repository, and the repository group "csm-noos." This helps ensure that nexus doesn't have any issues or conflicts when we upload the artifacts by bringing Nexus's csm-noos to a cleanslate.
* Recreates the respective csm-noos member repository and the csm-noos repository group.
* Uploads the artifacts to csm-noos member repository from the local repository .

## JIRA(s)

This hotfix covers the following JIRA(s):

> ***NOTE*** If/when additional RPMs are added, their corresponding JIRAs should be included here.

* [CAST-39550](https://jira-pro.it.hpe.com:8443/browse/CAST-39550)

## Usage

### Interactive

Run the script without arguments to witness a deterrent, and interactively accept the hotfix.

```bash
./install-hotfix.sh
```

### Non-interactive

Run the script with `-y` to proceed non-interactively.

```bash
./install-hotfix.sh -y
```
