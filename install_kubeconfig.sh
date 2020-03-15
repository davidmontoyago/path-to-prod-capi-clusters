#!/bin/sh
#
# installs a given kubeconfig file by merging it onto ~/.kube/config
#
set -eu -o pipefail

NEW_KUBECONFIG_FILE=$1
KCONFIG=$HOME/.kube/config
STAMP=$(date '+%Y-%m-%d-%H%M%S')
PWD=$(pwd)

cp "$KCONFIG" "$KCONFIG-backup-$STAMP"

# view --merge does not merge in new servers for when the server location has changed
CLUSTER_NAME=$(KUBECONFIG=$NEW_KUBECONFIG_FILE kubectl config get-clusters | tail -n1)
kubectl config delete-cluster $CLUSTER_NAME || true

# FIXME in kubeconfig, if usernames match across clusters then the user will conflict and not get udpated
# See https://github.com/kubernetes/kubernetes/issues/46381#issuecomment-553163639

KUBECONFIG="$KCONFIG:$PWD/$NEW_KUBECONFIG_FILE" kubectl config view --merge --flatten > ./tmp
mv ./tmp $KCONFIG