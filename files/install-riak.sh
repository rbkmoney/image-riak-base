#!/bin/bash
set -e eu

source /lib/gentoo/functions.sh
source /etc/portage/make.conf

# Build riak
mkdir -p /opt/riak
cd /opt/riak
curl -L -o riak.tar.gz https://github.com/basho/riak/archive/refs/tags/riak-${RIAK_VERSION}.tar.gz
echo "${RIAK_VERSION_HASH}  riak.tar.gz" | sha1sum -c -
tar xzf riak.tar.gz --strip-components=1
git apply < /riak.patch
make locked-deps
make rel OVERLAY_VARS="overlay_vars=/vars.config"
