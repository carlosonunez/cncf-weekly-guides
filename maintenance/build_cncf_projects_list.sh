#!/usr/bin/env bash
set -ex
DATA_VOL="${DATA_VOL:-/data}"
TODO_VOL="${TODO_VOL:-/todo}"
CONFIG_YAML_PATH="${CONFIG_YAML_PATH:-/config.yaml}"
CNCF_LANDSCAPE_URL="https://raw.githubusercontent.com/cncf/landscape/refs/heads/master/landscape.yml"

_fail_if_empty() {
  test -n "$1" && return 0

  >&2 echo "ERROR: $2"
  exit 1
}

blog_sitemap_url() {
  url=$(yq -r '.urls.blog' "$CONFIG_YAML_PATH")
  test -z "$url" && return 1

  echo "${url}/sitemap.xml"
}

get_current_cncf_projects_by_name() {
  curl -L "$CNCF_LANDSCAPE_URL" |
    yq -r '.landscape | to_entries[] | .value | to_entries[] | select(.key == "subcategories") | .value[].items[].name' |
    sort -u
}

get_done_cncf_weekly_projects_from_blog() {
  url=$(blog_sitemap_url)
  curl -L "$url" | yq -p=xml \
    '.urlset.url[] |
      select( 
        (.loc | contains("-init") | not) and 
        (.loc | contains("cncf-weekly-")) 
      ) | 
      ((.loc | split("-"))[-1] | sub("/",""))' |
  sort -u
}

get_last_list_of_cncf_projects_by_name() {
  test -f "${DATA_VOL}/cncf_projects_last_list.txt" || return 0
  cat "${DATA_VOL}/cncf_projects_last_list.txt"
}

update_last_cncf_projects_list() {
  echo "$1" > "${DATA_VOL}/cncf_projects_last_list.txt"
}

show_cncf_projects_diff() {
  delta=$(diff <(echo "$1") <(echo "$2")) || true
  test -z "$delta" && return 0

  >&2 echo "INFO: Projects list changed; diff shown below"
  echo "$delta"
}

fail_if_not_running_in_container() {
  # shellcheck disable=SC2154
  { test -f /.dockerenv || test "$container" == 'podman'; } && return 0

  >&2 echo "ERROR: This script is meant to be run within a container."
  exit 1
}

create_done_list() {
  local all finished
  all="$1"
  finished="$2"
  comm -12 <(echo "$all") <(echo "$finished") > "${TODO_VOL}/finished_projects.txt"
}

create_todo_list() {
  local all finished
  all="$1"
  finished="$2"
  comm -23 <(echo "$all") <(echo "$finished") > "${TODO_VOL}/todo_projects.txt"
}

fail_if_not_running_in_container
all_cncf_projects=$(get_current_cncf_projects_by_name)
_fail_if_empty "$all_cncf_projects" "Couldn't get CNCF projects."
last_cncf_projects=$(get_last_list_of_cncf_projects_by_name)
show_cncf_projects_diff "$last_cncf_projects" "$all_cncf_projects"
update_last_cncf_projects_list "$all_cncf_projects"
done_cncf_projects=$(get_done_cncf_weekly_projects_from_blog)
_fail_if_empty "$done_cncf_projects" "Couldn't get projects already covered by CNCF weekly."
create_done_list "$all_cncf_projects" "$done_cncf_projects"
create_todo_list "$all_cncf_projects" "$done_cncf_projects"
