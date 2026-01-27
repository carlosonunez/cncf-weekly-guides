#!/usr/bin/env bash
set -e

source "../include/helpers/config.sh"
source "../include/helpers/data.sh"
source "../include/helpers/errors.sh"

get_current_cncf_projects_by_name() {
  curl -sSL "https://raw.githubusercontent.com/cncf/landscape/refs/heads/master/landscape.yml" |
    yq -r '.landscape |
to_entries[] |
.value |
to_entries[] |
select(.key == "subcategories") |
.value[].items[].name' |
    grep -Ev ' \(.*\)$' |
    sort -u
}

get_done_cncf_weekly_projects_from_blog() {
  blog_url=$(_get_from_config '.urls.blog') || return 1
  curl -sSL "${blog_url}/sitemap.xml" | yq -p=xml \
    '.urlset.url[] |
      select( 
        (.loc | contains("-init") | not) and 
        (.loc | contains("cncf-weekly-")) 
      ) | 
      .loc' |
  sed -E 's/.*cncf-weekly-[0-9]{1,}-// ; s#/$##' |
  sort -u
}

get_last_list_of_cncf_projects_by_name() {
  cat "$(_get_file_from_data_vol 'cncf_projects_last_list.txt')"
}

update_last_cncf_projects_list() {
  echo "$1" > "$(_get_file_from_data_vol 'cncf_projects_last_list.txt')"
}

show_cncf_projects_diff() {
  delta=$(diff <(echo "$1") <(echo "$2")) || true
  test -z "$delta" && return 0

  >&2 echo "INFO: Projects list changed; diff shown below"
  echo "$delta"
}

create_done_list() {
  local all finished
  all="$1"
  finished="$2"
  _recreate_file_in_todo_vol 'finished_projects.txt'
  echo "$all" | grep -Ei "^($(tr '\n' '|' <<< "$finished" | sed -E 's/\|$//'))" > "$(_get_file_from_todo_vol 'finished_projects.txt')"
}

create_todo_list() {
  local all finished
  all="$1"
  finished="$2"
  _recreate_file_in_todo_vol 'todo_projects.txt'
  echo "$all" | grep -Evi "^($(tr '\n' '|' <<< "$finished" | sed -E 's/\|$//'))" > "$(_get_file_from_todo_vol 'todo_projects.txt')"
}

_fail_if_not_running_in_container

all_cncf_projects=$(get_current_cncf_projects_by_name)
_fail_if_empty "$all_cncf_projects" "Couldn't get CNCF projects."
last_cncf_projects=$(get_last_list_of_cncf_projects_by_name)
show_cncf_projects_diff "$last_cncf_projects" "$all_cncf_projects"
update_last_cncf_projects_list "$all_cncf_projects"
done_cncf_projects=$(get_done_cncf_weekly_projects_from_blog)
_fail_if_empty "$done_cncf_projects" "Couldn't get projects already covered by CNCF weekly."
create_done_list "$all_cncf_projects" "$done_cncf_projects"
create_todo_list "$all_cncf_projects" "$done_cncf_projects"
