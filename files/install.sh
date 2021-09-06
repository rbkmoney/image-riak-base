#!/bin/bash
set -e eu -x
DEST="/tmp/portage-root"

source /lib/gentoo/functions.sh
source /etc/portage/make.conf

GCC_LDPATH="$(gcc-config -L)"

# Build Erlang
echo dev-lang/erlang::rbkmoney ~amd64 >> /etc/portage/package.accept_keywords/erlang
emerge -t =dev-lang/erlang-22.1.8-r1::rbkmoney

quickpkg debianutils

# Build image
mkdir -p "${DEST}"/{etc,run,var,lib64,usr/lib64}/
ln -s /run "${DEST}/var/run"
ln -s /lib64 "${DEST}/lib"
ln -s /usr/lib64 "${DEST}/usr/lib64"

echo 'Europe/Moscow' > "${DEST}"/etc/timezone

export USE=unconfined
export ROOT="${DEST}"
emerge --getbinpkgonly sys-libs/glibc sys-libs/timezone-data
emerge -t sys-libs/zlib net-libs/libmnl dev-libs/elfutils \
       sys-apps/busybox app-shells/bash net-misc/curl dev-util/systemtap

equery s \*
# Link logger to busybox to avoid installing util-linux
ln -s -f /bin/busybox "${DEST}/usr/bin/logger"

mkdir -p "$(dirname "${DEST}${GCC_LDPATH}")"
cp -r "${GCC_LDPATH}" "${DEST}${GCC_LDPATH}"
cp /etc/ld.so.conf.d/05gcc-x86_64-pc-linux-gnu.conf \
   "${DEST}/etc/ld.so.conf.d/05gcc-x86_64-pc-linux-gnu.conf"
ldconfig -r "${DEST}"

# Install Nagios Scripts for monitoring Riak
emerge net-analyzer/riak_nagios

rm -rf "${DEST}/var/cache/edb"/*
