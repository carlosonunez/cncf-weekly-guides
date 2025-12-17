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


# Create base and cluster-level app directory structures
mkdir -p "$PWD/repo/apps/base/guestbook" "$PWD"/repo/apps/{dev,prod}

# Create a secret for the 'guestbook' app that we'll deploy and encrypt it
kubectl create secret generic guestbook-config \
  --from-literal=env-key=superdupersecret \
  --dry-run=client \
  -o yaml | sops --config "$PWD/repo/.sops.yaml" encrypt \
    --filename-override "$PWD/repo/apps/base/guestbook/secret.yaml" \
    --output "$PWD/repo/apps/base/guestbook/secret.yaml"

# Fetch the all-in-one guestbook manifest and store it into our app directory
curl -Lo "$PWD/repo/apps/base/guestbook/app.yaml" \
  https://raw.githubusercontent.com/kubernetes/examples/refs/heads/master/web/guestbook/all-in-one/guestbook-all-in-one.yaml

# Create the Kustomize manifest for the app so that Flux can render it
# Patch the deployment to introduce an environment variable created from our secret and change the
# Redis image it uses.
# This way, we can see the Flux sOps provider at work.
cat >"$PWD/repo/apps/base/guestbook/kustomization.yaml" <<-EOF
resources:
- app.yaml
- secret.yaml
patches:
  - target:
      kind: Deployment
      name: frontend
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 1
      - op: add
        path: /spec/template/spec/containers/0/env
        value:
          - name: SECRET_ENV_KEY
            valueFrom:
              secretKeyRef:
                name: guestbook-config
                key: env-key
  - target:
      kind: Deployment
      name: redis-master
    patch: |-
      - op: add
        path: /spec/template/spec/containers/0/image
        value: redis
EOF

# Add 'guestbook' to dev cluster apps
cat >"$PWD/repo/apps/dev/kustomization.yaml" <<-EOF
resources:
- ../base/guestbook
EOF

# Add 'guestbook' to prod cluster apps
cat >"$PWD/repo/apps/prod/kustomization.yaml" <<-EOF
resources:
- ../base/guestbook
EOF

# Install Kustomizations that will synchronize apps with their respective clusters
for env in dev prod
do
  # Prepare our Kubernetes cluster for flux
  kind get kubeconfig --name "cluster-$env" --internal > "$PWD/.kube/config"
  flux create kustomization cluster-apps \
    --context "kind-cluster-$env" \
    --target-namespace default \
    --source flux-system \
    --path ./apps/$env \
    --prune true \
    --wait true \
    --interval 1m \
    --retry-interval 30s \
    --health-check-timeout 10s \
    --decryption-provider=sops \
    --decryption-secret=sops-gpg \
    --export > "$PWD/repo/clusters/$env/apps-kustomization.yaml"
done

# Commit and push changes to apply. GitOps!
git -C "$PWD/repo" add apps clusters &&
  git -C "$PWD/repo" commit -m "install cluster apps" &&
  git -C "$PWD/repo" push

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

# Confirm that guestbook is running
kubectl --context "kind-cluster-dev" get deployment frontend # should be 1/1
kubectl --context "kind-cluster-prod" get deployment frontend # should be 1/1

for env in dev prod
do
  # Confirm that our secret was rendered
  >&2 echo "===> The secret in $env is: $(kubectl get secret --context "kind-cluster-$env" \
    guestbook-config -o jsonpath='{.data.env-key}' | base64 -d)"

  # Confirm that the secret was added to the frontend's environment
  kubectl --context "kind-cluster-$env" exec deployment/frontend -- \
    sh -c "echo \"The secret inside of the Pod in $env is: \$SECRET_ENV_KEY\""
done


# Let's increase the replica count for prod, since, well, production.
# We can do that in the production kustomization.
cat >"$PWD/repo/apps/prod/kustomization.yaml" <<-EOF
resources:
- ../base/guestbook
patches:
  - target:
      kind: Deployment
      name: frontend
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 2
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
kubectl --context "kind-cluster-dev" get deployment frontend # should be 1/1
kubectl --context "kind-cluster-prod" get deployment frontend # should be 2/2
