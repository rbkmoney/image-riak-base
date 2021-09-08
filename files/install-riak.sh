#!/bin/bash
set -e eu

source /lib/gentoo/functions.sh
source /etc/portage/make.conf

# Build riak
mkdir -p /opt/riak && cd /opt/riak
curl -L https://github.com/basho/riak/archive/refs/tags/riak-${riak_version}.tar.gz -o /opt/riak.tar.gz
echo "${riak_version_hash}  /opt/riak.tar.gz" | sha1sum -c -
tar zxf /opt/riak.tar.gz --strip-components 1
patch -p0 < /riak.schema.patch
patch < /rebar.config.patch
patch < /rebar.lock.patch
cp /vars.config /opt/riak/rel/vars.config
make rel
