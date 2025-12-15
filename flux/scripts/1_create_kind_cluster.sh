#!/usr/bin/env bash
set -x
export KIND_EXPERIMENTAL_PROVIDER=podman

for env in dev prod
do kind create cluster --name "cluster-$env"
done
