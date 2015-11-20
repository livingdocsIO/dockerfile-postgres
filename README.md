# Postgres 9.3 with plv8 extension (v1.4)

## Create a container and give it a name

```bash
docker run -p 5432:5432 --name postgres livingdocs/postgres
```


## Start an existing container

```bash
docker start postgres
```


## To build this image manually

```bash
docker build --tag livingdocs/postgres .
```
