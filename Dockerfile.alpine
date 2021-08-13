# Deprecated alpine image
# We don't continue to support that as building deps is more complicated
# e.g. pg_auto_failover doesn't support alpine linux.
# The debian-based image is only 30MB larger even with pg_auto_failover and pg_squeeze installed.
FROM golang:1.13.10-alpine3.11 AS walg
ENV WALG_VERSION=v0.2.19

RUN apk add --no-cache wget cmake git build-base bash
RUN git clone https://github.com/wal-g/wal-g/ $GOPATH/src/wal-g
RUN cd $GOPATH/src/wal-g/ \
  && git checkout $WALG_VERSION \
  && make install \
  && make deps \
  && make pg_build \
  && install main/pg/wal-g / \
  && /wal-g --help

FROM alpine
WORKDIR /var/lib/postgresql/data
VOLUME /var/lib/postgresql/data
VOLUME /var/run/postgresql

ENV PGUSER postgres
ENV PGHOST /var/run/postgresql
ENV PGDATA /var/lib/postgresql/data
ENV PAGER 'pspg -s 0'
ENV PATH="$PATH:/scripts"
ENV WALG_CONFIG_FILE=/etc/walg.yaml

RUN apk add --repository=http://dl-cdn.alpinelinux.org/alpine/edge/main postgresql postgresql-contrib && \
  apk add --no-cache bash curl nano pspg shadow su-exec jq && \
  usermod -u 1000 postgres && \
  groupmod -g 1000 postgres && \
  mkdir -p /var/lib/postgresql/initdb.d /var/run/postgresql && \
  chown -R postgres:postgres /var/lib/postgresql /var/run/postgresql && \
  apk del shadow

STOPSIGNAL SIGINT
COPY --from=walg /wal-g /usr/local/bin/wal-g
COPY --from=postgres:13-alpine /usr/local/bin/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
ADD ./scripts /scripts
ENTRYPOINT ["/scripts/entrypoint"]
CMD ["postgres"]
