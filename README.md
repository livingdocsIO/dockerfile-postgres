# Postgres 12

- Includes [wal-g](https://github.com/wal-g/wal-g) (wal archiving software)
- Simplifies streaming replication setups

## Create a container and give it a name

```bash
# Secured with a password, by default the image is secure
docker run -d --name postgres -p 5432:5432 -e POSTGRES_PASSWORD=somepassword livingdocs/postgres:12.2

```

## Start an existing container

```bash
docker start postgres
```


## To build this image manually

```bash
docker build -t livingdocs/postgres:12.2 .
```

## Set up streaming replication

### Simple setup
```bash
# Create the containers
docker run -d -p 5433:5432 --name postgres-1 livingdocs/postgres:12.2
docker run -d -p 5434:5432 --name postgres-2 livingdocs/postgres:12.2 standby -d "host=host.docker.internal port=5433 user=postgres"

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
docker run -d -p 5433:5432 --name postgres-1 -e POSTGRES_HOST_AUTH_METHOD=md5 -v $PWD/on_cluster_create.sql:/var/lib/postgresql/initdb.d/on_cluster_create.sql livingdocs/postgres:12.2
docker run -d -p 5434:5432 --name postgres-2 livingdocs/postgres:12.2 standby -d "host=host.docker.internal port=5433 user=replication password=some-replication-password"

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

1. either remove the `standby.signal` in the data directory `rm /var/lib/postgresql/data/standby.signal` on the replica
2. or execute `su-exec postgres pg_ctl promote` in the container
