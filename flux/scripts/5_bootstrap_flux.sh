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

# Post-bootstrap note: Add that some users might run into weird DNS
# issues depending on how DNS is set up in their environment and that
# they can do the below to alleviate:
#
# - `cd` into the `repo` directory
# - Open `clusters/$env/flux-system/gotk-components.yaml`
# - Search for `image: ` and add the following underneath every match:
#
# ```yaml
# dnsConfig:
#   options:
#   - name: ndots
#     value: "1"
# ```
#
# - Commit and push changes
# - Wait about a minute, then run `kubectl --context kind-cluster-$env
#   delete pod -n flux-system --all`
