#!/usr/bin/env bash
export KIND_EXPERIMENTAL_PROVIDER=podman

# Stop Git server
podman rm -f gitserver

# Turn down our cluster
for env in dev prod
do kind delete cluster --name "cluster-$env"
done

test -f "$HOME/.config/containers/.containers_conf_already_present" ||
  rm "$HOME/.config/containers/.containers.conf"

# Delete our repo and keys directories
rm -rf "$PWD/{repo,keys}"

# Delete our tools
for tool in kind fluxcd/tap/flux podman gnupg sops
do
  if test -f "/tmp/tool_already_installed_$(echo "$tool" | base64 -w 0)"
  then rm "/tmp/tool_already_installed_$(echo "$tool" | base64 -w 0)"
  else brew uninstall "$tool"
  fi
done

# Delete Podman machine
podman machine rm -f flux
