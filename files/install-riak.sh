#!/bin/bash
set -e eu

source /lib/gentoo/functions.sh
source /etc/portage/make.conf

# Build riak
export GIT_BRANCH_RIAK=riak-2.9.2

cd /opt
git clone -n -b $GIT_BRANCH_RIAK https://github.com/basho/riak.git riak
cd riak
git checkout -q $GIT_BRANCH_RIAK
git apply < /riak.patch
make locked-deps
patch -p 0 < /riak_core.patch
make rel OVERLAY_VARS="overlay_vars=/vars.config"
