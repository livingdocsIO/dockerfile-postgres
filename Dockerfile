FROM centos/postgresql-95-centos7

ENV PLV8_VERSION=1.4.8

USER root

RUN yum install -y epel-release && \
    INSTALL_PKGS="rh-postgresql95-postgresql-devel gcc gcc-c++ make openssl-devel v8-devel" && \
    yum -y --setopt=tsflags=nodocs install $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    cd /tmp && curl -L https://github.com/plv8/plv8/archive/v$PLV8_VERSION.tar.gz | tar -xz && \
    cd plv8-$PLV8_VERSION && PATH=/opt/rh/rh-postgresql95/root/usr/bin:$PATH make install && \
    cd / && rm -Rf /tmp/plv8-$PLV8_VERSION && \
    yum clean all && yum -y history undo last

USER 26
