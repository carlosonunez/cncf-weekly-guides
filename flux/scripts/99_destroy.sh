#!/usr/bin/env bash
set -x
export KIND_EXPERIMENTAL_PROVIDER=podman

# Stop Git server
podman rm -f -t 1 gitserver

# Turn down our cluster
for env in dev prod
do kind delete cluster --name "cluster-$env"
done

test -f "$HOME/.config/containers/.containers_conf_already_present" ||
  rm "$HOME/.config/containers/.containers.conf"

# Delete our repo and keys directories
rm -rf "$PWD/{repo,keys}"

# Delete Podman machine
podman machine rm -f flux

# Delete GPG key
fp=$(gpg --list-keys cluster | grep -A 1 pub | tail -1 | tr -d ' ')
gpg --delete-secret-and-public-keys --batch --yes "$fp"

# Delete our tools
for tool in kind podman gnupg sops
do
  if test -f "/tmp/tool_already_installed_$(echo "$tool" | base64 -w 0)"
  then rm "/tmp/tool_already_installed_$(echo "$tool" | base64 -w 0)"
  else brew uninstall "$tool"
  fi
done
