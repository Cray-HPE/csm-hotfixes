# Fixes and improvements for large scale CSM systems

## Prerequisites

- CSM version 1.6.0

## Changelog

- BOS
  - CASMCMS-9225: Improve performance of large GET components requests
  - CASMCMS-9242: Add BOS options: bss_read_timeout, ims_read_timeout, hsm_read_timeout, pcs_read_timeout
  - CASMCMS-9177: Have BOS migration job wait for databases to be ready before proceeding
- FAS
  - CASMHMS-6310: Fix FAS resource leaks
- `hmcollector`
  - CASMHMS-6295: Fix `hmcollector` resource leaks
- PCS
  - CASMHMS-6288: Configurable http timeout/retries
  - CASMHMS-6299: Fix PCS resource leaks
- SMD
  - CASMHMS-6294: Fix SMD resource leaks

## Installation

The `install-hotfix.sh` script may be run on any Master or Worker Non-Compute Node.
It will update the BOS, FAS, `hmcollector`, PCS, and SMD services.

Example:

```bash
./install-hotfix.sh
```

## Rollback

- To revert BOS to its previous version:

    ```bash
    helm -n services rollback cray-bos
    ```

- To revert FAS to its previous version:

    ```bash
    helm -n services rollback cray-hms-firmware-action
    ```

- To revert `hmcollector` to its previous version:

    ```bash
    helm -n services rollback cray-hms-hmcollector
    ```

- To revert PCS to its previous version:

    ```bash
    helm -n services rollback cray-power-control
    ```

- To revert SMD to its previous version:

    ```bash
    helm -n services rollback cray-hms-smd
    ```
