#!/bin/bash
set -e eu
DEST="/tmp/portage-root"

source /lib/gentoo/functions.sh
source /etc/portage/make.conf

GCC_LDPATH="$(gcc-config -L)"

# Build riak
export OPENSSL_VERSION=1.0.2u
export GIT_BRANCH_OTP=basho-otp-16
export GIT_BRANCH_RIAK=riak-2.9.0p5

# Build OpenSSL
cd /opt
curl -OL https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz;
tar -xf openssl-${OPENSSL_VERSION}.tar.gz;
cd openssl-${OPENSSL_VERSION}; \
    ./config shared no-krb5 -fPIC; \
    make depend; \
    make; \
    make install

# Build Erlang
cd /opt
git clone -n -b $GIT_BRANCH_OTP 'https://github.com/basho/otp.git' $GIT_BRANCH_OTP
cd $GIT_BRANCH_OTP; git checkout -q $GIT_BRANCH_OTP; \
    ./otp_build setup -a --prefix=/usr/local \
                         --enable-m64-build \
                         --with-ssl=/usr/local/ssl \
                         --without-odbc \
                         --disable-hipe \
                         --enable-smp-support \
                         --enable-threads \
                         --without-termcap \
                         --enable-kernel-poll; \
    make install

cd /opt
git clone -n -b $GIT_BRANCH_RIAK https://github.com/basho/riak.git riak;
cd riak; git checkout -q $GIT_BRANCH_RIAK;
mv /riak-rebar.config /opt/riak/rebar.config
mv /riak-reltool.config /opt/riak/rel/reltool.config
mv /riak.schema /opt/riak/rel/files/riak.schema
make lock
make rel OVERLAY_VARS="overlay_vars=/vars.config"

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
       sys-apps/busybox app-shells/bash net-misc/curl

equery s \*
# Link logger to busybox to avoid installing util-linux
ln -s -f /bin/busybox "${DEST}/usr/bin/logger"

mkdir -p "$(dirname "${DEST}${GCC_LDPATH}")"
cp -r "${GCC_LDPATH}" "${DEST}${GCC_LDPATH}"
cp /etc/ld.so.conf.d/05gcc-x86_64-pc-linux-gnu.conf \
   "${DEST}/etc/ld.so.conf.d/05gcc-x86_64-pc-linux-gnu.conf"
ldconfig -r "${DEST}"

rm -rf "${DEST}/var/cache/edb"/*
