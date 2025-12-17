#!/usr/bin/env bash
set -x
export KIND_EXPERIMENTAL_PROVIDER=podman
export GIT_CONFIG_SYSTEM=''
export GIT_CONFIG_GLOBAL=''

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

# Modify DNS config so that we don't run into DNS resolution errors within the Helm components
for env in dev prod
do
  cat >"$PWD/repo/clusters/$env/flux-system/kustomization.yaml" <<-EOF
  resources:
  - gotk-components.yaml
  - gotk-sync.yaml
  patches:
    - target:
        kind: Deployment
        labelSelector: app.kubernetes.io/part-of=flux
      patch: |
        - op: replace
          path: /spec/template/spec/dnsConfig
          value:
            options:
              - name: ndots
                value: "1"
EOF
  git -C "$PWD/repo" commit -m "modify DNS config for Helm components in env  $env" *kustomization.yaml
done

# Commit and push our changes.
git -C "$PWD/repo" push

# Wait again
last_sha=$(git -C "$PWD/repo" log -1 --format=%H)
for env in dev prod
do
  attempts=0
  while true
  do
    if test "$attempts" -gt 120
    then
      >&2 echo "Kustomization failed to sync at SHA $last_sha"
      exit 1
    fi
    kubectl --context "kind-cluster-$env" get kustomization flux-system -n flux-system |
      grep "Applied revision: master@sha1:$last_sha" && break
    attempts=$((attempts+1))
    sleep 1
  done
done

# Finally, add the GPG key to our clusters so that sOps can use it in Kustomizations
fp=$(gpg --list-keys cluster | grep -A 1 pub | tail -1 | tr -d ' ')
for env in dev prod
do gpg --export-secret-keys --armor "$fp" |
  kubectl --context "kind-cluster-${env}" create secret generic sops-gpg \
    -n flux-system \
    --from-file=sops.asc=/dev/stdin
done
