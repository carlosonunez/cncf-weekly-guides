#!/usr/bin/env bash
set -ex

export KIND_EXPERIMENTAL_PROVIDER=podman
export GIT_CONFIG_SYSTEM=''
export GIT_CONFIG_GLOBAL=''

flux() {
  podman run --rm -v "$PWD/keys:/keys" \
    -v "$PWD/.kube:/.kube" \
    --network=kind \
    fluxcd/flux-cli:v2.7.5 "$@"
}

# Let's use Flux to manage Helm charts.
#
# First, add a source for the chart repository containing our Helm chart.
mkdir -p "$PWD/repo/apps/base/hello-world"

# Create a source for our Helm chart repository.
# We'll use the 'dev' cluster; doesn't matter which since we're exporting it.
flux --context kind-cluster-dev create source helm helm-examples \
  --url https://helm.github.io/examples \
  --export > "$PWD/repo/apps/base/hello-world/source.yaml"

# Next, add a Helm release object to manage a chart with Flux.
flux --context kind-cluster-dev create helmrelease hello-world \
  --chart hello-world \
  --source HelmRepository/helm-examples \
  --chart-version 0.1.0 \
  --interval 1m \
  --export > "$PWD/repo/apps/base/hello-world/release.yaml"

# Create the kustomization to put it all together
cat >"$PWD/repo/apps/base/hello-world/kustomization.yaml" <<-EOF
resources:
- source.yaml
- release.yaml
EOF

# Commit our app
set +e
git -C "$PWD/repo" add apps
git -C "$PWD/repo" commit -m "add hello-world app" apps
set -e

# Let's install this into our clusters by adding it to our environment files.
# Add 'guestbook' to dev cluster apps
cat >"$PWD/repo/apps/dev/kustomization.yaml" <<-EOF
resources:
- ../base/guestbook
- ../base/hello-world
EOF

# Add 'guestbook' to prod cluster apps
cat >"$PWD/repo/apps/prod/kustomization.yaml" <<-EOF
resources:
- ../base/guestbook
- ../base/hello-world
EOF

# Commit and push changes to apply. GitOps!
set +e
git -C "$PWD/repo" add apps clusters &&
  git -C "$PWD/repo" commit -m "install cluster apps" &&
  git -C "$PWD/repo" push
set -e

# Wait for the synced Git commit of our Kustomization to match our latest commit
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
    kubectl --context "kind-cluster-$env" get kustomization cluster-apps -n flux-system |
      grep "Applied revision: master@sha1:$last_sha" && break
    attempts=$((attempts+1))
    sleep 1
  done
done

# Confirm that the deployment in production has scaled up while leaving the replica count in dev
# untouched.
kubectl --context "kind-cluster-dev" get deployment hello-world # should be 1/1
kubectl --context "kind-cluster-prod" get deployment hello-world # should be 1/1

# Let's change the replica count again in prod, but through Helm values.
cat >"$PWD/repo/apps/prod/kustomization.yaml" <<-EOF
resources:
- ../base/guestbook
- ../base/hello-world
patches:
  - target:
      kind: Deployment
      name: frontend
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 2
  - target:
      kind: HelmRelease
      name: hello-world
    patch: |-
      - op: replace
        path: /spec/values
        value:
          replicaCount: 2
EOF

# Commit and push our changes.
git -C "$PWD/repo" add apps clusters &&
  git -C "$PWD/repo" commit -m "increase replica count in prod" &&
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
    kubectl --context "kind-cluster-$env" get kustomization cluster-apps -n flux-system |
      grep "Applied revision: master@sha1:$last_sha" && break
    attempts=$((attempts+1))
    sleep 1
  done
done

# Confirm that the deployment in production has scaled up while leaving the replica count in dev
# untouched.
kubectl --context "kind-cluster-dev" get deployment hello-world # should be 1/1
kubectl --context "kind-cluster-prod" get deployment hello-world # should be 2/2
