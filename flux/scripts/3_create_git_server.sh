# Create a containerized Git server with our repo and keys in it.
docker run --platform=linux/amd64 --rm --network=kind -p 2222:22 -d \
  --name gitserver \
  -v $PWD/repo:/git-server/repos/infra \
  -v $PWD/keys:/git-server/keys \
  jkarlos/git-server-docker

# Confirm that the containerized Git server is up
ssh -i $PWD/keys/id_rsa git@127.0.0.1 -p 2222 | grep 'Welcome'

# Confirm that the containerized Git server is reachable from
# our Kind clusters
for env in dev prod
do
  docker exec -it "cluster-${env}-control-plane" curl --telnet-option FAKE=1 -sS telnet://gitserver:22
  echo "===> ${env}: $?"
done
