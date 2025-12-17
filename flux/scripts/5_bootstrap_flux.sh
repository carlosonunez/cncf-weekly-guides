#!/usr/bin/env bash
set -x
export KIND_EXPERIMENTAL_PROVIDER=podman

flux() {
  podman run --rm -v "$PWD/keys:/keys" \
    -v "$PWD/.kube:/.kube" \
    --network=kind \
    fluxcd/flux-cli:v2.7.5 "$@"
}

for env in dev prod
do
  >&2 echo "====> Cluster: $env"
  # Prepare our Kubernetes cluster for flux
  mkdir -p "$PWD/.kube"
  kind get kubeconfig --name "cluster-$env" --internal > "$PWD/.kube/config"
  # Check that your Kubernetes clusters are ready for flux...
  flux check --pre --context "kind-cluster-$env"

  # ...then bootstrap!
  flux bootstrap git \
    --url=ssh://git@gitserver/git-server/repos/platform \
    --path="./clusters/$env" \
    --branch master \
    --private-key-file="/keys/id_rsa" \
    --context "kind-cluster-$env" \
    --author-email 'clusterops@example.com' \
    --author-name 'Cluster Ops Bot' \
    --silent
done

# Flux commits cluster configurations to Git during the bootstrap process
# so that you can synchronize Flux settings with GitOps. 
# Pull in those changes.
git -C "$PWD/repo" pull --rebase

# Finally, add the GPG key to our clusters so that sOps can use it in Kustomizations
fp=$(gpg --list-keys cluster | grep -A 1 pub | tail -1 | tr -d ' ')
for env in dev prod
do gpg --export-secret-keys --armor "$fp" |
  kubectl --context "kind-cluster-${env}" create secret generic sops-gpg \
    -n flux-system \
    --from-file=sops.asc=/dev/stdin
done
