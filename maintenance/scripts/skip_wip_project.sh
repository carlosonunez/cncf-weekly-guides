#!/usr/bin/env bash
set -x

source "../include/helpers/config.sh"
source "../include/helpers/data.sh"
source "../include/helpers/errors.sh"

wip_project_present() {
  test -n "$(_get_file_from_todo_vol 'wip_project.txt')"
}

picked_project() {
  cat "$(_get_file_from_todo_vol 'wip_project.txt')"
}

unpick_project() {
  _recreate_file_in_todo_vol 'wip_project.txt'
}

picked_project_valid() {
  grep -Eq "^$(picked_project)$" "$(_get_file_from_todo_vol 'todo_projects.txt')"
}

mark_wip_project_as_skipped() {
  _create_file_in_todo_vol 'skipped_projects.txt'
  f="$(_get_file_from_todo_vol 'skipped_projects.txt')"
  grep -Eq "$(picked_project)" "$f" && return 0
  # shellcheck disable=SC2005
  echo "$(picked_project)" >> "$f"
}

_fail_if_not_running_in_container

if ! wip_project_present
then
  >&2 echo "ERROR: You're not working on any CNCF weeklies right now. Nothing to do."
  exit 0
fi
if ! picked_project_valid
then
  >&2 echo "ERROR: You're working on '$(picked_project)', but it's not valid?"
  exit 1
fi
>&2 echo "INFO: Marking '$(picked_project)' as skipped."
mark_wip_project_as_skipped
unpick_project
