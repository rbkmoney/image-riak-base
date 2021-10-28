#!/bin/bash
# set -e eu -x
set -x
DEST="/tmp/portage-root"

source /lib/gentoo/functions.sh
source /etc/portage/make.conf

GCC_LDPATH="$(gcc-config -L)"

# Build Erlang
echo dev-lang/erlang::rbkmoney ~amd64 >> /etc/portage/package.accept_keywords/erlang
emerge -t =dev-lang/erlang-22.3.4.21::rbkmoney

quickpkg --include-config=y sys-libs/glibc sys-libs/timezone-data \
	 sys-apps/debianutils sys-libs/zlib net-misc/curl

# Build image
mkdir -p "${DEST}"/{etc,run,var,lib,lib64,usr/lib,usr/lib64}/
ln -s /run "${DEST}/var/run"

echo 'Europe/Moscow' > "${DEST}"/etc/timezone

export USE=unconfined
emerge --buildpkgonly sys-apps/openrc
export ROOT="${DEST}"
ls -la "${DEST}/lib" "${DEST}/lib"/*
emerge --getbinpkgonly sys-libs/glibc sys-libs/timezone-data
emerge -t sys-libs/zlib net-libs/libmnl dev-libs/elfutils \
       sys-apps/busybox app-shells/bash net-misc/curl

ls -la "${DEST}/lib" "${DEST}/lib"/*
emerge --quiet-build=n --verbose sys-apps/openrc
ls -la "${DEST}/lib" "${DEST}/lib"/*
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
