#!/bin/bash

type curl 2>&1 >/dev/null || echo 2>& 'missing curl! script will fail'
PIT_VER=1.2.3-1
ILO_VER=3.2.3-1

function getdeps {
    curl -O https://packages.nmn/repository/casmrel-776/pit-init-${PIT_VER}.noarch.rpm
    curl -O https://packages.nmn/repository/casmrel-776/ilorest-${ILO_VER}.x86_64.rpm
}
