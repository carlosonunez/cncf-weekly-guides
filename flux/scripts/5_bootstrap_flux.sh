#!/usr/bin/env bash
set -x
export KIND_EXPERIMENTAL_PROVIDER=podman

for env in dev prod
do
  >&2 echo "====> Cluster: $env"
  # Prepare our Kubernetes cluster for flux
  mkdir -p "$PWD/.kube"
  kind get kubeconfig --name "cluster-$env" --internal > "$PWD/.kube/config"
  # Check that your Kubernetes clusters are ready for flux...
  podman run --rm -v "$PWD/.kube:/.kube" \
    --network=kind \
    fluxcd/flux-cli:v2.7.5 --context "kind-cluster-$env" check --pre

  # ...then bootstrap!
  podman run --rm -v "$PWD/keys:/keys" \
    -v "$PWD/.kube:/.kube" \
    --network=kind \
    fluxcd/flux-cli:v2.7.5 bootstrap git \
    --url=ssh://git@gitserver/git-server/repos/platform \
    --path="./clusters/$env" \
    --branch master \
    --private-key-file="/keys/id_rsa" \
    --context "kind-cluster-$env" \
    --author-email 'clusterops@example.com' \
    --author-name 'Cluster Ops Bot'
done
