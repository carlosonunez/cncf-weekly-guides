# Get the IP address of the containerized Git server that we created within the kind
# network our cluster is in
ip_address=$(docker inspect gitserver --format='{{.NetworkSettings.Networks.kind.IPAddress}}')

# Check that we can access our Git server within our Kind cluster.
kubectl run --image=alpine/git --command git-test -- sleep infinity
kubectl wait  --for=jsonpath='{.status.phase}'=Running pod/git-test
kubectl cp $PWD/keys/id_rsa git-test:/tmp/key
kubectl exec -it git-test -- git clone "ssh://git@$ip_address/git-server/repos/infra" \
  --config core.sshCommand="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i /tmp/key"

# Delete our test pod
kubectl delete pod git-test --grace-period=0
