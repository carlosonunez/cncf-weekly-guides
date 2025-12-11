# Turn down our cluster
for env in dev prod
do kind delete cluster --name "cluster-$env"
done

# Delete our repo and keys directories
rm -rf "$PWD/{repo,keys}"
