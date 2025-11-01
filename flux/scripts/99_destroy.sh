# Turn down our cluster
kind delete cluster --name flux

# Delete our repo and keys directories
rm -rf "$PWD/{repo,keys}"
