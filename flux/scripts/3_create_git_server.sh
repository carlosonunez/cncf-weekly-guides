#!/usr/bin/env bash
set -ex
export GIT_CONFIG_SYSTEM=''
export GIT_CONFIG_GLOBAL=''

# Create a containerized Git server with our repo and keys in it.
mkdir -p "$PWD/repo"
podman run --platform=linux/amd64 --rm --network=kind -p 2222:22 -d \
  --name gitserver \
  -v "$PWD/keys:/git-server/keys" \
  jkarlos/git-server-docker

# Confirm that the containerized Git server is up
ssh -i "$PWD/keys/id_rsa" git@127.0.0.1 -p 2222 | grep 'Welcome'

# Create a repo within the server
podman exec gitserver mkdir -p /git-server/repos/platform
podman exec gitserver git -C /git-server/repos/platform init --bare
podman exec gitserver chown -R git:git /git-server/repos/platform

# Clone it locally, add an initializing commit, then push back
git clone ssh://git@localhost:2222/git-server/repos/platform \
  --config core.sshCommand="ssh -i $PWD/keys/id_rsa" \
  "$PWD/repo"
git -C "$PWD/repo" commit --allow-empty -m "initial commit"
git -C "$PWD/repo" push

# Confirm that the containerized Git server is reachable from
# our Kind clusters
for env in dev prod
do
  kubectl="kubectl --context kind-cluster-${env}"
  $kubectl run --image=alpine/git --command git-test -- sleep infinity
  $kubectl wait  --for=jsonpath='{.status.phase}'=Running pod/git-test
  $kubectl cp $PWD/keys/id_rsa git-test:/tmp/key
  $kubectl exec -it git-test -- git clone "ssh://git@gitserver/git-server/repos/platform" /tmp/repo \
    --config core.sshCommand="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i /tmp/key"
  $kubectl exec -it git-test -- sh -c "echo '====> $env'; git -C /tmp/repo log -1"
  $kubectl exec -it git-test -- rm -r /tmp/repo
  $kubectl delete pod git-test --grace-period=0
done
