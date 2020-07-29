#!/bin/bash

# Maybe join to a cluster
if [[ -z "$($RIAK_ADMIN cluster status | egrep $COORDINATOR_NODE)" && "$COORDINATOR_NODE" != "$HOST" ]]; then
  # Not already in this cluster, so join
  echo "Connecting to cluster coordinator $COORDINATOR_NODE"
  # Token is any string, that can be used to bypass CSRF
#  TOKEN=$(/usr/bin/openssl rand -hex 12)
#  curl -sSL -X POST $HOST:8098/admin/cluster \
#       -d "{\"changes\":[{\"action\":\"join\",\"node\":\"$CLUSTER_NAME@$COORDINATOR_NODE_HOST\"}]}" \
#       -H "Content-Type: application/json" -b "csrf_token=$TOKEN" -H "X-CSRF-Token: $TOKEN"
  riak-admin cluster join $CLUSTER_NAME@$COORDINATOR_NODE
  riak-admin cluster plan
  riak-admin cluster commit
fi
