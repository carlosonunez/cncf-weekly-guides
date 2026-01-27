#!/usr/bin/env bash
set -e

source "../include/helpers/config.sh"
source "../include/helpers/data.sh"
source "../include/helpers/errors.sh"

wip_project_present() {
  test -n "$(_get_file_from_todo_vol 'wip_project.txt')"
}

picked_project() {
  cat "$(_get_file_from_todo_vol 'wip_project.txt')"
}

picked_project_already_finished() {
  grep -Eq "$(picked_project)" < <(_get_file_from_todo_vol 'finished_projects.txt')
}

unpick_project() {
  _recreate_file_in_todo_vol 'wip_project.txt'
}

pick_next_project() {
  num_todo_projects=$(cat "$(_get_file_from_todo_vol 'todo_projects.txt')" | wc -l)
  line="$((1 + RANDOM % num_todo_projects))"
  sed -n "${line}p" "$(_get_file_from_todo_vol 'todo_projects.txt')"
}

save_picked_project() {
  echo "$1" > "$(_get_file_from_todo_vol 'wip_project.txt')"
}

picked_project_valid() {
  grep -Eq "^$(picked_project)$" "$(_get_file_from_todo_vol 'todo_projects.txt')"
}

_fail_if_not_running_in_container
if wip_project_present
then
  if ! picked_project_valid
  then
    >&2 echo "ERROR: You're working on '$(picked_project)', but it's not valid?"
    exit 1
  fi
  if ! picked_project_already_finished
  then
    >&2 echo "ERROR: You're still working on '$(picked_project)'; ship it if you're done!"
    exit 1
  fi
  unpick_project
else _create_file_in_todo_vol 'wip_project.txt'
fi
project=$(pick_next_project)
save_picked_project "$project"
>&2 echo "INFO: Congrats! You're working on '$(picked_project)'. Get crackin'!"
