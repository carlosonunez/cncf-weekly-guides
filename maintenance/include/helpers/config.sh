# shellcheck shell=bash
CONFIG_FILE="${CONFIG_FILE:-/config.yaml}"

_get_from_config() {
  if ! test -f "$CONFIG_FILE"
  then
    >&2 echo "FATAL: config file not found at $CONFIG_FILE"
    exit 1
  fi
  res=$(yq -r "$1" "$CONFIG_FILE") || return 1
  if test "$res" == null
  then return 0
  fi
  echo "$res"
}
