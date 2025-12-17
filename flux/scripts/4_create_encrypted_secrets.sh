#!/usr/bin/env bash
set -ex
export GIT_CONFIG_SYSTEM=''
export GIT_CONFIG_GLOBAL=''

# Create our GPG key
gpg --quick-generate-key --batch --passphrase='' cluster

# Confirm our newly-created GPG key is present and get its
# fingerprint
fp=$(gpg --list-keys cluster | grep -A 1 pub | tail -1 | tr -d ' ')
echo "===> FP: $fp"

# Create our sOps creation rules...
cat >"$PWD/repo/.sops.yaml" <<-EOF
creation_rules:
  - path_regex: .*.yaml$
    pgp: $fp
    encrypted_regex: ^(data|stringData)$
EOF

# ...and commit our change, then push
git -C "$PWD/repo" add .sops.yaml
git -C "$PWD/repo" commit -m "add sOps config for secrets"
git -C "$PWD/repo" push

# Finally, add the GPG key to our clusters so that sOps can use it in Kustomizations
for env in dev prod
do gpg --export-secret-keys --armor "$fp" |
  kubectl --context "kind-cluster-${env}" create secret generic sops-gpg \
    -n flux-system \
    --from-file=sops.asc=/dev/stdin
done

