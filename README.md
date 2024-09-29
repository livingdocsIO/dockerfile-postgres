# [Postgres 16.4](https://github.com/livingdocsIO/dockerfile-postgres) [![](https://img.shields.io/badge/docker-livingdocs%2Fpostgres-blue)](https://hub.docker.com/r/livingdocs/postgres)

- Based on Debian
- Includes `postgres-contrib`, enables the extensions `pg_stat_statements` by default
- Includes [wal-g](https://github.com/wal-g/wal-g) for WAL archiving and shipping
- Includes [pg_auto_failover](https://github.com/citusdata/pg_auto_failover) for automatic failover
- Runs as postgres user with uid (1000), gid (1000)
- Does not try to fix permissions during boot to support a fast startup
- Does not have Dockerfile VOLUME declarations and therefore no issues with pg_upgrade --link
- Simplifies streaming replication setups by providing some simple commands

## Create a container and give it a name

```bash
# Secured with a password, by default the image is secure
docker run -d  --name postgres -p 5432:5432 -v postgres:/var/lib/postgresql -e POSTGRES_PASSWORD=somepassword livingdocs/postgres:16.4
```

## Upgrade an existing postgres container

```bash
# Let's assume you've created a container previously
docker run -d --name postgres -p 5432:5432 -v postgres:/var/lib/postgresql livingdocs/postgres:14.5

# First stop it, then run the upgrade image
docker stop postgres
docker run --rm -v postgres:/var/lib/postgresql livingdocs/postgres:16.4-upgrade

# After it succeeds, you can run the new image and mount the existing volume
docker run -d --name postgres -p 5432:5432 -v postgres:/var/lib/postgresql livingdocs/postgres:16.4
```

## To build this image manually

```bash
docker build -t livingdocs/postgres:16.4 .
```

With buildx on docker
```bash
# To build and push the multi-arch manifest to docker hub
docker buildx build --platform linux/amd64,linux/arm64 -t livingdocs/postgres:16.4 --push .

docker buildx build --platform linux/amd64,linux/arm64 -t livingdocs/postgres:16.4-upgrade --push  -f Dockerfile.upgrade .
```

With nerdctl on lima/containerd
```bash
nerdctl build --platform=amd64,arm64 -t livingdocs/postgres:16.4 .
nerdctl build --platform=amd64,arm64 -t livingdocs/postgres:16.4-upgrade -f Dockerfile.upgrade .

lima nerdctl push --all-platforms livingdocs/postgres:16.4
lima nerdctl push --all-platforms livingdocs/postgres:16.4-upgrade
```

## Set up streaming replication

### Simple setup
```bash
# Create the containers
docker run -d -p 5433:5432 --name postgres-1 livingdocs/postgres:16.4
docker run -d -p 5434:5432 --name postgres-2 livingdocs/postgres:16.4 standby -d "host=host.docker.internal port=5433 user=postgres target_session_attrs=read-write"

# Test the replication
docker exec postgres-1 psql -c "CREATE TABLE hello (value text); INSERT INTO hello(value) VALUES('world');"
docker exec postgres-2 psql -c "SELECT * FROM hello;"
# Output:
#   value
#  -------
#  world
#  (1 row)
```

### Advanced setup using passwords
```bash
# Create a docker network to emulate dns resolution in a production system
docker network create local

# First create the database primary
docker run -d -p 5433:5432 --name postgres-1 --network=local --network-alias=postgres -e POSTGRES_HOST_AUTH_METHOD=md5 livingdocs/postgres:16.4

# Create the users on database intialization
# You could also mount an sql or script into /var/lib/postgresql/initdb.d during cluster startup to execute the script automatically.
docker exec postgres-1 psql -c "ALTER ROLE postgres ENCRYPTED PASSWORD 'some-postgres-password';"
docker exec postgres-1 psql -c "CREATE USER replication REPLICATION LOGIN ENCRYPTED PASSWORD 'some-replication-password';"

# The launch the replicas
export DB_URL="host=postgres port=5432 user=replication password=some-replication-password target_session_attrs=read-write"
docker run -d -p 5434:5432 --name postgres-2 --network=local --network-alias=postgres livingdocs/postgres:16.4 standby -d $DB_URL
docker run -d -p 5435:5432 --name postgres-3 --network=local --network-alias=postgres livingdocs/postgres:16.4 standby -d $DB_URL

# Test the replication
docker exec postgres-1 psql -c "CREATE TABLE hello (value text); INSERT INTO hello(value) VALUES('hello');"
docker exec postgres-2 psql -c "SELECT * FROM hello;"
docker exec postgres-3 psql -c "SELECT * FROM hello;"
# Output for both instances:
#  value
# -------
# hello
# (1 row)


#
# Test a replica promotion (manually)
#
docker rm -f postgres-1

# Inserts will still fail into slaves: ERROR:  cannot execute INSERT in a read-only transaction
docker exec postgres-2 psql -c "INSERT INTO hello(value) VALUES('world');"

# Promote a slave
docker exec postgres-2 touch /var/lib/postgresql/data/promote.signal

# And test it
docker exec postgres-2 psql -c "INSERT INTO hello(value) VALUES('world');"
docker exec postgres-3 psql -c "SELECT * FROM hello;"
# Output for both instances:
#  value
# -------
#  hello
#  world
# (2 rows)
```

## To promote a replica to a primary
Please make sure that first the old master doesn't accept any writes anymore.
Either stop it or reject writes:
```sql
ALTER SYSTEM SET default_transaction_read_only TO 'on';
SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pid <> pg_backend_pid();
```

Then promote the replica. There are two options:
- Create the `promote.signal` in the data directory `touch /var/lib/postgresql/data/promote.signal` on the replica.
  If you've changed your configuration, make sure `promote_trigger_file` declares that path.
- Execute `gosu postgres pg_ctl promote` in the container.
