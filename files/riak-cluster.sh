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
export SCHEMAS_DIR=/usr/lib/riak/share/schema/

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
$(RIAK) start
$(RIAK) admin wait-for-service riak_kv

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
  $(RIAK) ping >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    exit 1
  fi
  sleep 10
done
