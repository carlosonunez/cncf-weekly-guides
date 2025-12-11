for env in dev prod
do kind create cluster --name "cluster-$env"
done
