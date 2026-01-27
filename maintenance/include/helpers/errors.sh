# shellcheck shell=bash

_fail_if_empty() {
  local v msg
  v="$1"
  msg="$2"
  test -n "$v" && return 0
  >&2 echo "ERROR: $msg"
  exit 1
}

_fail_if_not_running_in_container() {
  # shellcheck disable=SC2154
  { test -f /.dockerenv || test "$container" == 'podman'; } && return 0

  >&2 echo "FATAL: This script is meant to be run within a container."
  exit 1
}

