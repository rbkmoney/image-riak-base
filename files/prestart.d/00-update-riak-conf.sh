#!/bin/bash

# Add standard config items
cat <<END >>$RIAK_CONF
nodename = $CLUSTER_NAME@$HOST
distributed_cookie = $CLUSTER_NAME
listener.protobuf.internal = $HOSTIP:$PB_PORT
listener.http.internal = $HOSTIP:$HTTP_PORT
END

# Maybe add user config items
if [ -s $USER_CONF ]; then
  cat $USER_CONF >>$RIAK_CONF
fi
