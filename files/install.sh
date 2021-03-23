#!/bin/bash
set -e eu -x
DEST="/tmp/portage-root"

source /lib/gentoo/functions.sh
source /etc/portage/make.conf

GCC_LDPATH="$(gcc-config -L)"

# Build riak
export OPENSSL_VERSION=1.0.2u
export BASHO_OTP_COMMIT=f873cae9e03c997c22832162d9b5cd307d35b7e5

# Build OpenSSL
cd /opt
curl -OL "https://www.openssl.org/source/old/1.0.2/openssl-${OPENSSL_VERSION}.tar.gz"
tar -xf "openssl-${OPENSSL_VERSION}.tar.gz"
cd "openssl-${OPENSSL_VERSION}"
./config shared no-krb5 -fPIC
make depend
make
make install

# Build Erlang
emerge -t dev-util/systemtap
cd /opt
curl -L "https://github.com/basho/otp/archive/${BASHO_OTP_COMMIT}.tar.gz" -o basho-otp.tar.gz
tar -xf basho-otp.tar.gz
ls
cd "otp-${BASHO_OTP_COMMIT}"
OLD_CXXFLAGS="${CXXFLAGS}"
export CPPFLAGS="${CXXFLAGS} -DEPMD6"
patch -p 0 < /erlang_otp.patch
./otp_build setup -a --prefix=/usr/local \
            --enable-m64-build \
            --with-ssl=/usr/local/ssl \
            --without-odbc \
            --enable-hipe \
            --enable-smp-support \
            --enable-threads \
            --with-dynamic-trace=systemtap \
            --enable-kernel-poll
make install
export CPPFLAGS="${OLD_CXXFLAGS}"

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
