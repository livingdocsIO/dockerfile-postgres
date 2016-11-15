FROM postgres:9.6
MAINTAINER Marc Bachmann <marc@livingdocs.io>

ENV PLV8_VERSION 1.4.8
RUN apt-get update && apt-get upgrade -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --force-yes --no-install-recommends \
    build-essential curl ca-certificates libv8-dev postgresql-server-dev-$PG_MAJOR && \

   	# Install plv8
	cd /tmp && curl -L https://github.com/plv8/plv8/archive/v$PLV8_VERSION.tar.gz | tar -xz && \
	cd plv8-$PLV8_VERSION && make all install && \
	cd / && rm -Rf /tmp/plv8-$PLV8_VERSION && \

    # cleanup
    apt-get autoremove -y && apt-get clean && \
    rm -Rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
