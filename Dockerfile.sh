#!/bin/sh
cat <<EOF
FROM ${REGISTRY}/${ORG_NAME}/build:${BUILD_IMAGE_TAG} as build
RUN rm -r /etc/portage/repos.conf/*.conf \
    /etc/portage/savedconfig/* \
    /etc/portage/package.mask/*
COPY files/portage/ /etc/portage
COPY portage/ /usr/portage
COPY overlays/ /var/lib/layman

ARG riak_version
ARG riak_version_hash
ENV RIAK_HOME /usr/lib/riak
ENV RIAK_FLAVOR KV

COPY files/install.sh /
COPY files/install-riak.sh /
COPY files/vars.config /
COPY files/rebar.config.patch /
COPY files/rebar.lock.patch /
COPY files/riak.schema.patch /
RUN /install.sh
RUN /install-riak.sh

# Install custom hooks
COPY files/prestart.d /tmp/portage-root/etc/riak/prestart.d
COPY files/poststart.d /tmp/portage-root/etc/riak/poststart.d

# Install custom start script
COPY files/riak-cluster.sh /tmp/portage-root/riak-cluster.sh

#####################################################################
# Riak image
FROM scratch
COPY --from=build /tmp/portage-root/ /

# Prepare directrories
RUN mkdir -p /etc/riak/prestart.d /etc/riak/poststart.d \
    /usr/lib/riak/ /var/lib/riak /var/log/riak

# Copy riak sources
COPY --from=build /opt/riak/rel/riak/lib /usr/lib/riak/lib
COPY --from=build /opt/riak/rel/riak/share /usr/lib/riak/share
COPY --from=build /opt/riak/rel/riak/erts-10.7.2.13 /usr/lib/riak/erts-10.7.2.13
COPY --from=build /opt/riak/rel/riak/releases /usr/lib/riak/releases
COPY --from=build /opt/riak/rel/riak/bin /usr/lib/riak/bin
COPY --from=build /opt/riak/rel/riak/etc/* /etc/riak/
COPY --from=build /opt/riak/rel/riak/data/* /var/lib/riak/data/

RUN busybox --install
LABEL com.rbkmoney.${SERVICE_NAME}.parent=null \
    com.rbkmoney.${SERVICE_NAME}.parent_tag=null  \
    com.rbkmoney.${SERVICE_NAME}.branch=${BRANCH}  \
    com.rbkmoney.${SERVICE_NAME}.commit_id=${COMMIT}  \
    com.rbkmoney.${SERVICE_NAME}.commit_number=`git rev-list --count HEAD`

# Expose default ports
EXPOSE 8087
EXPOSE 8098

# Create riak user/group
RUN touch /etc/group /etc/passwd
RUN adduser -u 0 -g wheel -D -h /root root; \
    adduser -u 102 -g riak -D -h /var/lib/riak riak; \
    chown -R riak:riak /var/lib/riak /var/log/riak

# Expose volumes for data and logs
VOLUME /var/log/riak
VOLUME /var/lib/riak

ENV RIAK_HOME /usr/lib/riak
ENV RIAK_FLAVOR KV

# HACKS to make image work as desired
RUN ln -s /usr/lib/riak/bin/riak /usr/sbin/riak
# HACKS to make image work as desired

WORKDIR /var/lib/riak
RUN chmod a+x /riak-cluster.sh
CMD ["/riak-cluster.sh"]

EOF
