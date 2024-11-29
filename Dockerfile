FROM debian:bookworm-slim
WORKDIR /var/lib/postgresql

# Volume mounts should happen on /var/lib/postgresql and /var/run/postgresql
#
# We don't use VOLUME declarations like in the offical image as
# it just causes file permission issues and slow start times if we try
# to fix permissions during boot.
#
# And they won't work well with pg_upgrade and the --link argument,
# which greatly improves the upgrade speed of major versions.
ADD ./scripts /scripts
RUN /scripts/postgres-install && rm /scripts/postgres-install

USER postgres
ENV PG_MAJOR=16
ENV PGUSER=postgres
ENV PGHOST /var/run/postgresql
ENV PGPORT 5432
ENV PGDATA /var/lib/postgresql/data
ENV PAGER 'pspg -s 0'
ENV PATH="$PATH:/usr/lib/postgresql/16/bin:/scripts"
ENV WALG_CONFIG_FILE=/var/lib/postgresql/.walg.json
ENV LANG en_US.utf8

COPY --from=postgres:16.6 /usr/local/bin/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
ADD ./scripts /scripts

STOPSIGNAL SIGINT
ENTRYPOINT ["/scripts/entrypoint"]
CMD ["postgres"]
