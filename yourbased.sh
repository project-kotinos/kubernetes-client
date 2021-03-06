#!/usr/bin/env bash
set -ex
export DEBIAN_FRONTEND=noninteractive

kube_version=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)
curl -LO https://storage.googleapis.com/kubernetes-release/release/${kube_version}/bin/linux/amd64/kubectl && \
    chmod +x kubectl && mv kubectl /usr/local/bin/
echo "Installed kubectl CLI tool"
echo "Installing nsenter"
if ! which nsenter > /dev/null; then
  echo "Did not find nsenter. Installing it."
  NSENTER_BUILD_DIR=$(mktemp -d /tmp/nsenter-build-XXXXXX)
  pushd ${NSENTER_BUILD_DIR}
  curl https://www.kernel.org/pub/linux/utils/util-linux/v2.31/util-linux-2.31.tar.gz | tar -zxf-
  cd util-linux-2.31
  ./configure --without-ncurses
  make nsenter
  cp nsenter /usr/local/bin
  rm -rf "${NSENTER_BUILD_DIR}"
  popd
fi
if ! which systemd-run > /dev/null; then
  echo "Did not find systemd-run. Hacking it to work around Kubernetes calling it."
  echo '#!/bin/bash
  echo "all arguments: "$@
  while [[ $# -gt 0 ]]
  do
    key="$1"
    if [[ "${key}" != "--" ]]; then
      shift
      continue
    fi
    shift
    break
  done
  echo "remaining args: "$@
  exec $@' | tee /usr/bin/systemd-run >/dev/null
  chmod +x /usr/bin/systemd-run
fi
oc_tool_version="openshift-origin-client-tools-v3.10.0-dd10d17-linux-64bit"
curl -LO https://github.com/openshift/origin/releases/download/v3.10.0/${oc_tool_version}.tar.gz && \
    tar -xvzf ${oc_tool_version}.tar.gz && chmod +x $PWD/${oc_tool_version}/oc && mv $PWD/${oc_tool_version}/oc /usr/local/bin/ && \
    rm -rf ${oc_tool_version}.tar.gz
echo "Installed OC CLI tool"
tmp=`mktemp`
echo 'DOCKER_OPTS="$DOCKER_OPTS --insecure-registry 172.30.0.0/16"' > ${tmp}
mv ${tmp} /etc/default/docker
mount --make-shared /
service docker restart
echo "Configured Docker daemon with insecure-registry"
oc cluster up
sleep 10
oc login -u system:admin
echo "Configured OpenShift cluster : v3.10.0"
