FROM debian:bullseye-slim
WORKDIR /var/lib/postgresql

# Volume mounts should happen on /var/lib/postgresql and /var/run/postgresql
#
# We don't use VOLUME declarations like in the offical image as
# it just causes file permission issues and slow start times if we try
# to fix permissions during boot.
#
# And they won't work well with pg_upgrade and the --link argument,
# which greatly improves the upgrade speed of major versions.

RUN set -e \
  export DEBIAN_FRONTEND=noninteractive && \
  apt-get update && apt-get upgrade -y && \
	groupadd -r postgres --gid=1000 && \
	useradd -r -g postgres --uid=1000 --home-dir=/var/lib/postgresql --shell=/bin/bash postgres && \
	mkdir -p /var/lib/postgresql /var/run/postgresql /var/lib/postgresql/initdb.d && chown -R postgres:postgres /var/lib/postgresql /var/run/postgresql && \
  apt-get install -y curl nano pspg procps gosu dnsutils gnupg git && \
  # Alias gosu as the scripts are still used for alpine linux
  ln -s /usr/sbin/gosu /usr/sbin/su-exec && \
  echo "Install Postgres" && \
  sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt bullseye-pgdg main 14" > /etc/apt/sources.list.d/pgdg.list' && \
  sh -c 'curl -s https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -' && \
  apt-get update && \
  apt-get install -y --no-install-recommends postgresql-common && \
	sed -ri 's/#(create_main_cluster) .*$/\1 = false/' /etc/postgresql-common/createcluster.conf && \
	apt-get install -y --no-install-recommends "postgresql-14=14.0-1.pgdg110+1" && \
  echo 'Install pg_auto_failover' && \
  sh -c 'curl https://install.citusdata.com/community/deb.sh | bash' && \
  apt-get install -y postgresql-14-auto-failover-1.6.2 && \
  echo 'Install wal-g' && \
  curl -L https://github.com/wal-g/wal-g/releases/download/v1.1/wal-g-pg-ubuntu-18.04-amd64 > /usr/local/bin/wal-g && \
  chmod +x /usr/local/bin/wal-g && \
  # We need to have locales enabled for postgres
  grep -q '/usr/share/locale' /etc/dpkg/dpkg.cfg.d/docker && \
  sed -ri '/\/usr\/share\/locale/d' /etc/dpkg/dpkg.cfg.d/docker && \
  ! grep -q '/usr/share/locale' /etc/dpkg/dpkg.cfg.d/docker && \
	apt-get update; apt-get install -y --no-install-recommends locales && \
	localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 && \
  # Install pg_squeeze
  apt-get install -y postgresql-server-dev-14 build-essential && \
  git clone https://github.com/cybertec-postgresql/pg_squeeze.git /tmp/pg_squeeze && \
  cd /tmp/pg_squeeze && git checkout REL1_4 && make && make install && \
  # Cleanup
  apt-get purge -y --auto-remove apt-transport-https gnupg git postgresql-server-dev-14 build-essential && \
  apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/log/*

USER postgres
ENV PG_MAJOR=14
ENV PGUSER=postgres
ENV PGHOST /var/run/postgresql
ENV PGPORT 5432
ENV PGDATA /var/lib/postgresql/data
ENV PAGER 'pspg -s 0'
ENV PATH="$PATH:/usr/lib/postgresql/14/bin:/scripts"
ENV WALG_CONFIG_FILE=/var/lib/postgresql/.walg.json
ENV LANG en_US.utf8

COPY --from=postgres:14 /usr/local/bin/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
ADD ./scripts /scripts

STOPSIGNAL SIGINT
ENTRYPOINT ["/scripts/entrypoint"]
CMD ["postgres"]
