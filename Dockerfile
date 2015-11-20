
FROM postgres:9.3
MAINTAINER Marc Bachmann <marc@livingdocs.io>

RUN apt-get update && apt-get upgrade -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --force-yes --no-install-recommends \
    build-essential ca-certificates libv8-dev git-core postgresql-server-dev-$PG_MAJOR \

    # cleanup
    && apt-get autoremove -y && apt-get clean && \
    rm -Rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV PLV8_BRANCH r1.4
RUN cd /tmp && git clone -b $PLV8_BRANCH https://github.com/plv8/plv8.git \
  && cd /tmp/plv8 \
  && make all install \
  && cd /tmp && rm -Rf plv8
