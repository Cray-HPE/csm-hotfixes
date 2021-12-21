# Disable JndiLookup.class in strimzi operator

This hotfix applies to CSM 0.9.X (Shasta 1.4) and CSM 1.0.X (Shasta 1.5)

This fix Updates the strimzi operator 0.15.0 container to 0.15.0-noJndiLookupClass.
This container contains a version of log4j with the JdniLookup.class removed.

## How to install

Run the `./install-hotfix.sh` script in this hotfix.
