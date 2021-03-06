#!/bin/bash
#
# Cluster start script to bootstrap a Riak cluster.
#
sleep 10
set -ex

if [[ -x /usr/sbin/riak ]]; then
  export RIAK=/usr/sbin/riak
else
  export RIAK=$RIAK_HOME/bin/riak
fi
export RIAK_CONF=/etc/riak/riak.conf
export USER_CONF=/etc/riak/user.conf
export RIAK_ADVANCED_CONF=/etc/riak/advanced.config
if [[ -x /usr/sbin/riak-admin ]]; then
  export RIAK_ADMIN=/usr/sbin/riak-admin
else
  export RIAK_ADMIN=$RIAK_HOME/bin/riak-admin
fi
export SCHEMAS_DIR=/etc/riak/schemas/

# Set ports for PB and HTTP
export PB_PORT=${PB_PORT:-8087}
export HTTP_PORT=${HTTP_PORT:-8098}

# Use ping to discover our HOSTNAME because it's easier and more reliable than other methods
export HOST=${NODENAME:-$(hostname -f)}
export HOSTIP=$(hostname -i)
# CLUSTER_NAME is used to name the nodes and is the value used in the distributed cookie
export CLUSTER_NAME=${CLUSTER_NAME:-riak}

# The COORDINATOR_NODE is the first node in a cluster to which other nodes will eventually join
export COORDINATOR_NODE=${COORDINATOR_NODE:-$HOSTNAME}
export COORDINATOR_NODE_HOST=$(ping -c1 $COORDINATOR_NODE | awk '/^PING/ {print $3}' | sed -e 's/[()]//g' -e 's/:$//') || '127.0.0.1'

# Run all prestart scripts
PRESTART=$(find /etc/riak/prestart.d -name *.sh -print | sort)
for s in $PRESTART; do
  . $s
done

# Start the node and wait until fully up
# `riak start` command can be configured through env variables (e.g, WAIT_FOR_ERLANG).
# However, `riak` resets all env variables if the user is different from riak.
# So let's use su to pass the current environment into `riak` script.
su riak -c "$RIAK start"
$RIAK_ADMIN wait-for-service riak_kv

# Run all poststart scripts
POSTSTART=$(find /etc/riak/poststart.d -name *.sh -print | sort)
for s in $POSTSTART; do
  . $s
done

SIGTERM_TRAP_CMD="set -x ; $RIAK stop"

# Tail the log file indefinitely if asked to
if [[ -n "${RUNNER_TAIL_LOGS}" ]]; then
  tail -n 1024 -f /var/log/riak/console.log &
  RUNNER_TAIL_LOGGER_PID=$!
  SIGTERM_TRAP_CMD="$SIGTERM_TRAP_CMD ; kill $RUNNER_TAIL_LOGGER_PID"
fi

# Trap SIGTERM and SIGINT
trap "$SIGTERM_TRAP_CMD" SIGTERM SIGINT

# avoid log spamming and unnecessary exit once `riak ping` fails
set +ex
while :
do
  riak ping >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    exit 1
  fi
  sleep 10
done
