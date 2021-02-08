# [Postgres 13.1](https://github.com/livingdocsIO/dockerfile-postgres) [![](https://shields.beevelop.com/docker/pulls/livingdocs/postgres.svg?style=flat-square)](https://hub.docker.com/r/livingdocs/postgres)

- Includes postgres-contrib and enables `pg_stat_statements` by default
- Includes [wal-g](https://github.com/wal-g/wal-g) (wal archiving software)
- Simplifies streaming replication setups by providing some simple commands

## Create a container and give it a name

```bash
# Secured with a password, by default the image is secure
docker run -d --name postgres -p 5432:5432 -e POSTGRES_PASSWORD=somepassword livingdocs/postgres:13.1

```

## Start an existing container

```bash
docker start postgres
```


## To build this image manually

```bash
docker build -t livingdocs/postgres:13.1 .
```

## Set up streaming replication

### Simple setup
```bash
# Create the containers
docker run -d -p 5433:5432 --name postgres-1 livingdocs/postgres:13.1
docker run -d -p 5434:5432 --name postgres-2 livingdocs/postgres:13.1 standby -d "host=host.docker.internal port=5433 user=postgres target_session_attrs=read-write"

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
# Create the users on database intialization
# Everything in the /var/lib/postgresql/initdb.d directory gets automatically executed
echo "ALTER ROLE postgres ENCRYPTED PASSWORD 'some-postgres-password';" >> on_cluster_create.sql
echo "CREATE USER replication REPLICATION LOGIN ENCRYPTED PASSWORD 'some-replication-password';" >> on_cluster_create.sql

# Create the containers
docker run -d -p 5433:5432 --name postgres-1 -e POSTGRES_HOST_AUTH_METHOD=md5 -v $PWD/on_cluster_create.sql:/var/lib/postgresql/initdb.d/on_cluster_create.sql livingdocs/postgres:13.1
docker run -d -p 5434:5432 --name postgres-2 livingdocs/postgres:13.1 standby -d "host=host.docker.internal port=5433 user=replication password=some-replication-password target_session_attrs=read-write"

# Test the replication
docker exec postgres-1 psql -c "CREATE TABLE hello (value text); INSERT INTO hello(value) VALUES('world');"
docker exec postgres-2 psql -c "SELECT * FROM hello;"
# Output:
#   value
#  -------
#  world
#  (1 row)
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
- Execute `su-exec postgres pg_ctl promote` in the container.
