# Rename This Hotfix

> Do not publish this hotfix as a CAST ticket.

Debug versions of CMS iPXE:
- cms-ipxe-1.12.1: shipped with CSM V1.5.1, contains ipxe-tpsw-clone@v3.0.0
- cms-ipxe-1.13.0: next release that contains an iPXE source refresh (ipxe-tpsw-clone@v4.0.0) 

Includes debug flags:

- `httpcore:7`
- `x509:7`
- `efi_time:7`
- `http:7`
- `entropy:7`
- `tls:7`
- `drbg:7`
- `rbg:7`
- `efi_rng:7`
- `efi_entropy:7`

## Usage

- Install newer CMS iPXE with debug:

    ```bash
    ./install-hotfix-new-ipxe.sh
    ```

- Install CSM 1.5.1's CMS iPXE with debug:

    ```bash
    ./install-hotfix-1.5.1-ipxe.sh
    ```

- Revert back to the original CMS iPXE that shipped in CSM 1.5.1:

    ```bash
    ./uninstall-hotfix.sh
    ```
