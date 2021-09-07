#!/bin/bash
set -e eu

source /lib/gentoo/functions.sh
source /etc/portage/make.conf

# Build riak
export RIAK_VERSION=3.0.7

cd /opt
curl -L https://github.com/basho/riak/archive/refs/tags/riak-${RIAK_VERSION}.tar.gz -o riak.tar.gz
#6b061612f538e2f40f58d762c1ce62ec68ea9f3a  riak.tar.gz
tar zxf riak.tar.gz
mv riak-riak-${RIAK_VERSION} riak
cd riak
patch -p0 < /riak.schema.patch
patch < /rebar.config.patch
patch < /rebar.lock.patch
make rel OVERLAY_VARS="overlay_vars=/vars.config"
