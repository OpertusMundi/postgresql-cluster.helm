FROM redhat/ubi8:8.8 AS su-exec-builder

RUN dnf -y install git-core gcc make && dnf clean all

RUN git clone -b master https://github.com/ncopa/su-exec.git /opt/su-exec && \
  make -C /opt/su-exec


FROM redhat/ubi8:8.8

ARG POSTGRES_MAJOR_VERSION="15"

RUN dnf -y update && \
  dnf -y install https://www.pgpool.net/yum/rpms/4.4/redhat/rhel-8-x86_64/pgpool-II-release-4.4-1.noarch.rpm && \
  dnf -y install procps pgpool-II-pg${POSTGRES_MAJOR_VERSION} && \
  dnf clean all

COPY --from=su-exec-builder /opt/su-exec/su-exec /usr/local/bin

COPY --chown=postgres:postgres pool_hba.conf pgpool.conf.template /etc/pgpool-II/

ENV POOL_PASSWD_FILE="/etc/pgpool-II/pool_passwd" \
    POOL_HBA_FILE="/etc/pgpool-II/pool_hba.conf" \
    POOL_HBA_ALLOW_NON_SSL="off" \
    PCP_SOCKET_DIR="/var/run/pgpool" \
    PGPOOL_CONFIG_DIR="/etc/pgpool-II" \
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

RUN mkdir /var/lib/pgpool/ /var/lib/pgsql /var/log/pgpool && \
  chown -v postgres:postgres /var/lib/pgpool/ /var/lib/pgsql /var/log/pgpool

STOPSIGNAL SIGINT
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["pgpool", "-n", "-D", "-F", "/var/lib/pgpool/pcp.conf"]
