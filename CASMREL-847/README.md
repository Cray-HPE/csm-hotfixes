# Disable JndiLookup.class in strimzi operator

This hotfix applies to CSM 0.9.X (Shasta 1.4) and CSM 1.0.X (Shasta 1.5)

This fix addresses **CVE-2021-44228** in the strimzi operator 0.15.0 container. The new container contains a version of log4j with the JdniLookup.class removed.

>**NOTE**
>
> The fix removes `JdniLookup.class` from affected log4j jar files but it doesn't change the verion of jar files. That may cause false postive reports from certain scanning tools.

## How to install

Run the `./install-hotfix.sh` script in this hotfix.
