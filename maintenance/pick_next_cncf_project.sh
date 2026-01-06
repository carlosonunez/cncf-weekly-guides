#!/usr/bin/env bash
set -e
DATA_VOL="${DATA_VOL:-/data}"
TODO_VOL="${TODO_VOL:-/todo}"
get_random_id() {
  test -f "${DATA_VOL}/.cncf_next_project_id" || return 1
  cat "${DATA_VOL}/.cncf_next_project_id"
}

fail_if_not_running_in_container() {
  # shellcheck disable=SC2154
  { test -f /.dockerenv || test "$container" == 'podman'; } && return 0

  >&2 echo "ERROR: This script is meant to be run within a container."
  exit 1
}

fail_if_not_running_in_container
if random_id_already_generated || last_project_is_now_done
then regenerate_random_id
fi
>&2 echo "INFO: Project: $(project_from_random_id) [id: $(random_id)"
