set shell := [ "bash", "-euc" ]
set working-directory := 'maintenance'

update_containerized_config: 
  sops --decrypt $PWD/config.yaml | docker compose run --rm --quiet update_containerized_config

pick_next_cncf_project:
  just update_containerized_config || exit 1
  docker compose run --build --quiet --rm pick-next-cncf-project
