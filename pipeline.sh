#!/bin/sh

set -e

TMP_DIR=$(mktemp -d -t hive-XXXXX)

echo "Working in temp dir: $TMP_DIR"

pushd $TMP_DIR

git clone git@github.com:dgoodwin/hive-argocd-demo.git
# Clear all past manifests:
rm -rf hive-argocd-demo/manifests
mkdir hive-argocd-demo/manifests

git clone git@github.com:openshift/hive.git
pushd hive
GIT_HASH=`git rev-parse --short=7 HEAD`
IMG="quay.io/dgoodwin/hive:$GIT_HASH"
echo "Building hive image $IMG"
podman build -t $IMG .
podman push $IMG

# Kustomize manifests:
cd config
cp namespace.yaml $TMP_DIR/hive-argocd-demo/manifests/00-hive-namespace.yaml
kustomize edit set image registry.ci.openshift.org/openshift/hive-v4.0:hive=${IMG}
kustomize edit set namespace hive
kustomize build > $TMP_DIR/hive-argocd-demo/manifests/hive-operator.yaml
# Copy all CRD yaml:
cp crds/* $TMP_DIR/hive-argocd-demo/manifests/
popd # leave hive

pushd hive-argocd-demo
git add manifests/
git commit -a -m "Hive manifests update for $IMG"
git push
popd

echo "Pipeline complete, removing $TMP_DIR"
rm -rf $TMP_DIR
