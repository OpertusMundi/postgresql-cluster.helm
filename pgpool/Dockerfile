# vim: set syntax=dockerfile:

FROM debian:10.11-slim AS build-stage-1

ENV PGPOOL_VERSION="4.2.6"

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
  && apt-get install -y --no-install-recommends gcc build-essential libpq-dev libssl-dev libpam0g-dev \
  && rm -rf /var/lib/apt/lists/*

ADD https://www.pgpool.net/mediawiki/download.php?f=pgpool-II-${PGPOOL_VERSION}.tar.gz /opt/pgpool-II-${PGPOOL_VERSION}.tar.gz
RUN tar xzf /opt/pgpool-II-${PGPOOL_VERSION}.tar.gz -C /opt/
WORKDIR /opt/pgpool-II-${PGPOOL_VERSION}
RUN ./configure --prefix=/usr/local --with-openssl --with-pam && make && make install


FROM debian:10.11-slim

ENV PGPOOL_VERSION="4.2.6"

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
  && apt-get install -y --no-install-recommends gosu libpq5 libssl1.1 libpam0g \
  && rm -rf /var/lib/apt/lists/*

RUN groupadd -g 999 postgres \
  && useradd -g 999 -u 999 -M postgres

RUN mkdir -p /var/run/pgpool /var/local/lib/pgpool \
  && chown postgres:postgres /var/run/pgpool /var/local/lib/pgpool \
  && chmod 0775 /var/run/pgpool /var/local/lib/pgpool

COPY --from=build-stage-1 /usr/local/ /usr/local/
ENV LD_LIBRARY_PATH="/usr/local/lib"

COPY --chown=root:postgres pool_hba.conf pgpool.conf.template /usr/local/etc/

ENV POOL_PASSWD_FILE="/usr/local/etc/pool_passwd" \
    PGPOOL_ADMIN_USER="pgpool" \
    PGPOOL_ADMIN_PASSWORD_FILE="/secrets/pgpool-admin-password" \
    MONITOR_USER="monitor" \
    MONITOR_PASSWORD_FILE="/secrets/monitor-password" \
    USER_PASSWORDS_DIR="/secrets/users/" \
    TLS_KEY_FILE="/certs/pgpool.key" \
    TLS_CERT_FILE="/certs/pgpool.crt" \
    NUM_PROCS="32" \
    POOL_SIZE="4" \
    CHILD_LIFE_TIME="5min" \
    CLIENT_IDLE_LIMIT="0" \
    LOAD_BALANCE="on" \
    BACKEND_0_HOST="localhost" \
    BACKEND_0_PORT="5432" \
    BACKEND_0_WEIGHT="1" \
    BACKEND_0_NAME="server1"

COPY docker-entrypoint.sh /
RUN chmod 0744 /docker-entrypoint.sh

STOPSIGNAL SIGINT
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/usr/local/bin/pgpool", "-n", "-D"]

