#!/bin/bash
set -e eu

source /lib/gentoo/functions.sh
source /etc/portage/make.conf

# Port 9418 (git://) is blocked on the XPAY network while github https
# works. rebar3 resolves some transitive deps (lager et al.) to git://
# URLs declared in parent deps' configs, which the rebar.* seds below
# never see — rewrite them all at the git layer instead.
git config --global url."https://github.com/".insteadOf "git://github.com/"

# Build riak
mkdir -p /opt/riak && cd /opt/riak
curl -L https://github.com/basho/riak/archive/refs/tags/riak-${riak_version}.tar.gz -o /opt/riak.tar.gz
echo "${riak_version_hash}  /opt/riak.tar.gz" | sha256sum -c -
tar zxf /opt/riak.tar.gz --strip-components 1
patch -p0 < /riak.schema.patch
patch < /rebar.config.patch
patch < /rebar.lock.patch

export DIAGNOSTIC=1
grep upgrade Makefile
grep -lr 'git://github.com/' .
sed -e 's|git://github.com/|https://github.com/|g' -i rebar.*

# Two lock/config defects to repair for the modern tree:
# 1. yokozuna is pinned to the develop-3.0 branch (deleted upstream) and
#    is commented out of the config — drop its stale lock entries.
# 2. lager pulls goldrush as a hex-style dep, and the bundled rebar3
#    resolves hex packages via the registry protocol hex.pm retired.
#    Convert it to the git source in BOTH config and lock.
sed -i '/yokozuna/d' rebar.lock
sed -i 's|{deps, \[|{deps, [\n        {goldrush, {git, "https://github.com/basho/goldrush.git", {tag, "0.1.9"}}},|' rebar.config
sed -i 's|{ref,"22e62f28e5afabe90a6f31bcde367a2b5799fc94"}},|{ref,"22e62f28e5afabe90a6f31bcde367a2b5799fc94"}},\n {<<"goldrush">>,\n  {git,"https://github.com/basho/goldrush.git",\n       {ref,"8f1b715d36b650ec1e1f5612c00e28af6ab0de82"}},\n  1},|' rebar.lock

# clique declares cuttlefish as a branch dep (develop-3.0 — deleted
# upstream; the failed fetch is tolerated by the release but poisons the
# log). Pin it top-level to the exact upstream tag riak 3.0.9's lock
# carries (2.1.0 = ref e84070b) so resolution never consults the branch.
sed -i 's|{deps, \[|{deps, [\n        {cuttlefish, {git, "https://github.com/basho/cuttlefish.git", {tag, "2.1.0"}}},|' rebar.config

# The tarball's bundled rebar3 resolves hex packages via the registry
# protocol hex.pm retired — swap in rebar3 3.15.2, which speaks the modern
# per-package API and still runs on OTP 22.
curl -sL -o rebar3 https://github.com/rebar/rebar3/releases/download/3.15.2/rebar3
chmod +x rebar3
# 0.2.0's relx calls break on rebar3 3.15's bundled relx; 0.2.1 demands
# cuttlefish @ branch develop-3.0 (deleted upstream — the plugin then
# fails to load and the release ships without riak.conf/app.config).
# 0.3.0 uses the live develop branch, and its schema-lock git hooks are
# satisfied by the .git synthesis loop below.
sed -i 's|{tag, "0.2.0"}}}|{tag, "0.3.0"}}}|' rebar.config

./rebar3 upgrade
grep -lr 'git://github.com/' .
sed -e 's|git://github.com/|https://github.com/|g' -i $(grep -lr 'git://github.com/' .)
make compile

sed -e 's|debian/vars.config|/vars.config|g' -i rebar.config

# The cuttlefish plugin's schema lock runs `git rev-parse --verify HEAD`
# in every app dir. Rebar3 3.15+ checkouts (and riak's own apps) carry no
# .git, so synthesize repos to keep the rev-parse happy.
for appdir in _build/default/lib/* apps/*; do
    [ -d "$appdir" ] || continue
    [ -e "$appdir/.git" ] && continue
    git -C "$appdir" init -q 2>/dev/null || continue
    git -C "$appdir" add -A 2>/dev/null
    git -C "$appdir" -c user.email=build@localhost -c user.name=build \
        commit -qm "interim build" 2>/dev/null
done

./rebar3 as deb release --overlay_vars /vars.config

# The cf_config hook resolves schemas from $RELEASE_ROOT_DIR/share/schema,
# and upstream's riak_packager populates it from the app priv dirs.
# The deb flow we reuse skips that step.
mkdir -p _build/deb/rel/riak/share/schema
cp _build/default/lib/*/priv/*.schema _build/deb/rel/riak/share/schema/

# The plugin's build-time cuttlefish (develop tip) appends a conf.d
# include directive the release's runtime cuttlefish (2.1.0, per the
# project lock) cannot parse — and the image ships no conf.d anyway.
sed -i '/^include conf.d/d' _build/deb/rel/riak/etc/riak.conf

# cf_config boots the node with riak.conf's long nodename
# (riak@127.0.0.1), but the runner's ping/RPC path re-derives the name
# from the packaged releases vm.args, which ships a short -sname —
# align the two or the node is invisible to its own management
# commands.
sed -i 's/^-sname .*/-name riak@127.0.0.1/' _build/deb/rel/riak/releases/3.0.9/vm.args

tree .
ls -la _build/deb/rel/riak/bin
ls -la _build/deb/rel/riak/usr/bin

grep -r relx_nodetool .
cd _build/deb/rel/riak/bin
chmod +x nodetool

# riak_nagios (interim hacky build): the checks are escripts invoked via
# `riak escript` at runtime (see check_node_wrapper), so they only need to
# exist in the image. Compiled on the container's OTP 22 with the repo's
# bundled rebar, getopt/eunit_helper deps fetch from github.
git clone -q https://github.com/niku64/riak_nagios /opt/riak_nagios
cd /opt/riak_nagios
make escript
mkdir -p /tmp/portage-root/usr/lib64/nagios/plugins/riak
cp -a check_node bin/* /tmp/portage-root/usr/lib64/nagios/plugins/riak/
cp /tmp/data/check_node_wrapper /tmp/portage-root/usr/lib64/nagios/plugins/riak/

# The relx runner's admin/RPC helpers and the nagios wrapper's cookie
# grep both read the classic $RUNNER_ETC_DIR/vm.args, which the 3.x deb
# release does not ship — provide it, matching riak.conf's nodename.
mkdir -p /tmp/portage-root/etc/riak
cat <<EOF > /tmp/portage-root/etc/riak/vm.args
## Name of the node
-name riak@127.0.0.1

## Cookie for distributed erlang
-setcookie riak
EOF

# node_package-era riak-admin commands rpc through `relx_nodetool` on
# PATH. and a bare symlink to nodetool passes no name or cookie, every
# command reports "Node undefined". Ship a shim deriving them from the
# vm.args above instead. relx's nodetool consults the trailing args as
# a single Erlang term and calls Fun(ParsedArgs), while this generation
# of console modules is uniformly Fun(Args)/1 — so reshape
# `rpc Mod Fun a b c` into the consultable term [["a","b","c"]] (and
# bare `rpc Mod Fun` into [[]]) to match.
mkdir -p /tmp/portage-root/usr/sbin
cat <<'EOF' > /tmp/portage-root/usr/sbin/relx_nodetool
#!/bin/sh
NAME="$(awk '/^-name/{print $2}' /etc/riak/vm.args)"
COOKIE="$(awk '/^-setcookie/{print $2}' /etc/riak/vm.args)"

if [ "$1" = "rpc" ] && [ $# -ge 3 ]; then
    cmd="$1"; mod="$2"; fun="$3"; shift 3
    inner=""
    for a in "$@"; do
        e=$(printf '%s' "$a" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
        inner="$inner\"$e\","
    done
    if [ -n "$inner" ]; then
        set -- "$cmd" "$mod" "$fun" "[[${inner%,}]]"
    else
        set -- "$cmd" "$mod" "$fun" "[[]]"
    fi
fi

ERTS_SCRIPT="$(ls /usr/lib/riak/erts-*/bin/escript | head -n 1)"
exec "$ERTS_SCRIPT" /usr/lib/riak/bin/nodetool -name "$NAME" -setcookie "$COOKIE" "$@"
EOF
chmod +x /tmp/portage-root/usr/sbin/relx_nodetool
