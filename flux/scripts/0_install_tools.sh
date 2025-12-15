#!/usr/bin/env bash
set -x
for tool in kind podman gnupg sops
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

cpus=$(sysctl -n hw.ncpu)
mem_size="$(echo "$(sysctl -n hw.memsize)/1000000" | bc)"

podman machine init --cpus "$(echo "${cpus}/3" | bc)" \
  --memory "$(echo "${mem_size}/4" |bc)" \
  flux
podman machine start flux
