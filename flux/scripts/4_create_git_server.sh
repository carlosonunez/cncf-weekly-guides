# Create a containerized Git server with our repo and keys in it.
docker run --rm --network=kind -p 2222:22 -d \
  --name gitserver \
  -v $PWD/repo:/git-server/repos/infra \
  -v $PWD/keys:/git-server/keys \
  jkarlos/git-server-docker

# Confirm that the containerized Git server is up
ssh -i $PWD/keys/id_rsa git@127.0.0.1 -p 2222 | grep 'Welcome'
