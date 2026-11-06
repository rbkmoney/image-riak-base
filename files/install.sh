#!/bin/bash
set -e eu -x
DEST="/tmp/portage-root"

source /lib/gentoo/functions.sh
source /etc/portage/make.conf

GCC_LDPATH="$(gcc-config -L)"
ERLANG_VERSION="22.3.4.21::xpay"

# Purge the parent's OTP-28 stack: riak 3.0.9 must be built with OTP 22
# (the release embeds its own erts), and elixir/rebar/certifi pin the
# container to erlang >= 26. The final image carries riak's embedded erts
# instead of a portage erlang.
ERLANG_STACK="$(qlist -Iv | grep -E '^(dev-erlang/|dev-lang/elixir|dev-lang/erlang|dev-util/rebar)')"
if [ -n "${ERLANG_STACK}" ]; then
    emerge -C --quiet ${ERLANG_STACK}
fi

# Build Erlang
echo dev-lang/erlang::xpay ~amd64 >> /etc/portage/package.accept_keywords/erlang
emerge -t "=dev-lang/erlang-${ERLANG_VERSION}" dev-debug/strace

# quickpkg crashes in its ewarn path under python3.14 (Atom vs str, portage
# bug) after writing the binpkgs — tolerate and keep them.
quickpkg --include-config=y sys-libs/glibc sys-libs/timezone-data \
	 sys-apps/debianutils sys-libs/zlib net-misc/curl dev-lang/erlang \
	 dev-debug/strace || true

# Build image using merged-usr root layout.
mkdir -p "${DEST}"/{etc,run,var,usr/{bin,sbin,lib,lib64}}/
ln -s /run "${DEST}/var/run"
ln -s usr/bin "${DEST}/bin"
ln -s usr/sbin "${DEST}/sbin"
ln -s usr/lib "${DEST}/lib"
ln -s usr/lib64 "${DEST}/lib64"
# usr/lib stays a real directory (not lib64-symlinked), because
# portage's merged-usr internal-collision check refuses packages
# that install non-identical libs into the collapsed pair (libunistring).

echo 'Europe/Moscow' > "${DEST}"/etc/timezone

export USE=unconfined
# getuto (binhost key trust) runs against the target root on the first
# --getbinpkgonly emerge, give it the gentoo-release key up front.
ROOT="${DEST}" FEATURES=-getbinpkg emerge sec-keys/openpgp-keys-gentoo-release
# sys-libs/pam (pulled into the target root) builds SAG docs
# unconditionally and resolves the docbook XSL through the build env's
# XML catalog — same pre-seed as image-embedded's install.sh.
emerge app-text/docbook-xsl-ns-stylesheets
export ROOT="${DEST}"
emerge --getbinpkgonly sys-libs/glibc sys-libs/timezone-data --quiet-build=n --verbose
emerge -t sys-libs/zlib sys-libs/timezone-data sys-apps/debianutils net-libs/libmnl dev-libs/elfutils dev-libs/openssl-compat \
       sys-apps/busybox app-shells/bash net-misc/curl dev-debug/strace
rm -rf "${DEST}"/var/cache/{edb,binpkgs,distfiles}

# Link logger to busybox to avoid installing util-linux
ln -s -f /bin/busybox "${DEST}/usr/bin/logger"

mkdir -p "$(dirname "${DEST}${GCC_LDPATH}")"
cp -r "${GCC_LDPATH}" "${DEST}${GCC_LDPATH}"
cp /etc/ld.so.conf.d/05gcc-x86_64-pc-linux-gnu.conf \
   "${DEST}/etc/ld.so.conf.d/05gcc-x86_64-pc-linux-gnu.conf"
ldconfig -r "${DEST}"

# Install Nagios Scripts for monitoring Riak
emerge "=dev-lang/erlang-${ERLANG_VERSION}" net-analyzer/riak_nagios

einfo "Remove caches and temporary files from DEST"
rm -rf "${DEST}/var/cache/edb"/* "${DEST}"/var/cache/binpkgs "${DEST}"/var/cache/distfiles || exit $?
