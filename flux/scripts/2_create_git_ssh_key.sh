#!/usr/bin/env bash
set -x
mkdir -p $PWD/keys
ssh-keygen -t rsa -f "$PWD/keys/id_rsa" -qN ''
