# shellcheck shell=bash
DATA_VOL="${DATA_VOL:-/data}"
SECRETS_VOL="${SECRETS_VOL:-/secrets}"
TODO_VOL="${TODO_VOL:-/todo}"

_get() {
  f="${1}/${2}"
  test -f "$f" || return 1
  echo "$f"
}

_create() {
  local recreate
  recreate="$3"
  f="${1}/${2}"
  if test -f "$f" && test -z "$recreate"
  then
    >&2 echo "ERROR: File exists: $f"
    return 1
  fi
  test -n "$recreate" && rm -f "$f"
  touch "$f"

}

_get_file_from_data_vol() {
  _get "${DATA_VOL}" "$1"
}

_get_secret() {
  _get "${SECRETS_VOL}" "$1"
}

_get_file_from_todo_vol() {
  _get "${TODO_VOL}" "$1"
}

_create_file_in_todo_vol() {
  _create "${TODO_VOL}" "$1"
}

_recreate_file_in_todo_vol() {
  _create "${TODO_VOL}" "$1" true
}
