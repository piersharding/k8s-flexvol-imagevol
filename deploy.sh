#!/bin/sh

# Copyright 2019 Piers harding.
#
# Deploy the FlexVolume driver imagevol
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o pipefail

# TODO change to your desired driver name.
VENDOR=${VENDOR:-piersharding}
DRIVER=${DRIVER:-imagevol}
CTR_VERSION=${CTR_VERSION:-1.3.0}
JQ_VERSION=${JQ_VERSION:-1.6}
DRIVER_LOCATION=${DRIVER_LOCATION:-/usr/libexec/kubernetes/kubelet-plugins/volume/}
RUNTIME_ENDPOINT=${RUNTIME_ENDPOINT:-/run/containerd/containerd.sock}
HOST_TARGET=${HOST_TARGET:-/var/tmp/images}
DEBUG=${DEBUG:-false}

cd /flexmnt

# the driver uses ctr for image pull and export
if [ ! `which ctr` ]; then
  echo "no existing ctr"
  if [ ! -f "/flexmnt/ctr" ]; then
    echo "no ctr in /flexmnt"
    rm -f /flexmnt/containerd-$CTR_VERSION.linux-amd64.tar.gz
    wget -O /flexmnt/containerd-$CTR_VERSION.linux-amd64.tar.gz https://github.com/containerd/containerd/releases/download/v$CTR_VERSION/containerd-$CTR_VERSION.linux-amd64.tar.gz
    tar zxvf containerd-$CTR_VERSION.linux-amd64.tar.gz bin/ctr -C /flexmnt
    mv bin/ctr /flexmnt/ctr
    chmod a+x /flexmnt/ctr
    rm -rf /flexmnt/containerd-$CTR_VERSION.linux-amd64.tar.gz /flexmnt/bin
  fi
  CTR_EXE="${DRIVER_LOCATION}/ctr"
else
  CTR_EXE=`which ctr`
fi
echo "ctr at: $(ls -latr /flexmnt/ctr)"

# jq is used for parsing out details passed to driver
if [ ! `which jq` ]; then
  echo "no existing jq"
  JQ_EXE="${DRIVER_LOCATION}/jq"
  if [ ! -f "/flexmnt/jq" ]; then
    echo "no jq in /flexmnt"
    rm -f /flexmnt/jq-linux64
    wget -O /flexmnt/jq-linux64 https://github.com/stedolan/jq/releases/download/jq-${JQ_VERSION}/jq-linux64
    mv /flexmnt/jq-linux64 /flexmnt/jq
    chmod a+x /flexmnt/jq
  fi
else
  JQ_EXE=`which jq`
fi
echo "jq at: $(ls -latr /flexmnt/jq)"

# set the environment file for the driver
cat <<EOF >/flexmnt/imagevol_env.rc
DRIVER_LOCATION=${DRIVER_LOCATION}
RUNTIME_ENDPOINT=${RUNTIME_ENDPOINT}
CTR_EXE=${CTR_EXE}
JQ_EXE=${JQ_EXE}
HOST_TARGET=${HOST_TARGET}
DEBUG=${DEBUG}
EOF
echo "configuration in /flexmnt/imagevol_env.rc:"
cat /flexmnt/imagevol_env.rc

driver_dir=$VENDOR${VENDOR:+"~"}${DRIVER}
if [ ! -d "/flexmnt/exec/$driver_dir" ]; then
  mkdir -p "/flexmnt/exec/$driver_dir"
fi

tmp_driver=.tmp_$DRIVER
cp "/$DRIVER" "/flexmnt/exec/$driver_dir/$tmp_driver"
mv -f "/flexmnt/exec/$driver_dir/$tmp_driver" "/flexmnt/exec/$driver_dir/$DRIVER"

printf "\n\n\n##### Deployment Complete #####\n"

while : ; do
  sleep 3600
done
