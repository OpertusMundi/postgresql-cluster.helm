FROM alpine:3.18

RUN apk update && apk add --no-cache pgpool su-exec bash

RUN mkdir /var/run/pgpool /var/lib/pgpool /var/lib/postgresql && \
    chown root:postgres /var/run/pgpool /var/lib/pgpool /etc/pgpool && \
    chmod 0775 /var/run/pgpool /var/lib/pgpool /etc/pgpool && \
    chown postgres:postgres /var/lib/postgresql
COPY --chown=root:postgres pool_hba.conf pgpool.conf.template /etc/pgpool/

ENV POOL_PASSWD_FILE="/etc/pgpool/pool_passwd" \
    POOL_HBA_FILE="/etc/pgpool/pool_hba.conf" \
    POOL_HBA_ALLOW_NON_SSL="off" \
    PCP_SOCKET_DIR="/var/run/pgpool" \
    PGPOOL_ADMIN_USER="pgpool" \
    PGPOOL_ADMIN_PASSWORD_FILE="/secrets/pgpool-admin-password" \
    PGPOOLKEYFILE="/secrets/pgpool-key" \
    AUTH_METHOD="md5" \
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
    HEALTH_CHECK_PERIOD="90" \
    HEALTH_CHECK_MAX_RETRIES="3" \
    HEALTH_CHECK_RETRY_DELAY="15" \
    BACKEND_0_HOST="localhost" \
    BACKEND_0_PORT="5432" \
    BACKEND_0_WEIGHT="1" \
    BACKEND_0_NAME="server1"

COPY docker-entrypoint.sh /
RUN chmod 0744 /docker-entrypoint.sh

STOPSIGNAL SIGINT
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["pgpool", "-n", "-D", "-F", "/var/lib/pgpool/pcp.conf"]

