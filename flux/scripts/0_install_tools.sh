#!/usr/bin/env bash
for tool in kind fluxcd/tap/flux podman gnupg sops
do
  if brew list | grep -q "$tool"
  then touch "/tmp/tool_already_installed_$(echo "$tool" | base64 -w 0)"
  else brew install "$tool"
  fi
done

if test -f "$HOME/.config/containers/containers.conf"
then touch "$HOME/.config/containers/.containers_conf_already_present"
else cat >"$HOME/.config/containers/containers.conf" <<-EOF
[machine]
rosetta=false
EOF
fi

for op in init start
do podman machine "$op" flux
done
