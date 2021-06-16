# Unknown TPM Error - Diskboot

 
This hotfix will remove the tpm module from the diskbootloader's grub.cfg file.
This module was harmless in-house, but has proven to be problematic in some
cases (for unknown reasons). Therefore disabling it will provide better
assurance for disk boots.

## How to Use

Run the `install.sh` file, this will mount the BOOTRAID (if not already) and
rotate a new grub.cfg file into place. Once the script exits, the system can
diskboot once more.
