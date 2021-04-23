#!/bin/bash

for ns in $(kubectl get ns --no-headers=true -o custom-columns=":metadata.name"); do
  for pod in $(kubectl get pods -n "$ns" --no-headers -o custom-columns=":metadata.name"); do
    if [ ! -n "$(kubectl get pods -n "$ns" "$pod" -o jsonpath='{.metadata.annotations.kubernetes\.io/psp}')" ]; then 
    echo "PSP Missing for Pod $pod; namespace: $ns"
    fi
  done
done
