#!/bin/bash
set -e
set -x

replication_user="${REPLICATION_USER}"
replication_pass="$(cat ${REPLICATION_PASSWORD_FILE})"
pass_file=~/.pgpass
db_host=${MASTER_DB_HOST:-localhost}

if [ -n "$(ls -A ${PGDATA})" ]; then
    echo "The target directory (${PGDATA}) is not empty. Nothing to do." 1>&2
    exit 0
fi

retry_count=25
retry_interval=2
while ! pg_isready -h ${db_host}; do
    sleep ${retry_interval}
    retry_count=$((retry_count - 1))
    test $retry_count -ne 0
done

# Take basebackup

echo "${db_host}:5432:*:${replication_user}:${replication_pass}" > ${pass_file}
chmod 0600 ${pass_file}

pg_basebackup -v --checkpoint=fast -h ${db_host} -U ${replication_user} -D ${PGDATA}

# Generate recovery.conf

cat <<EOD > ${PGDATA}/recovery.conf
standby_mode = 'on'
primary_conninfo = 'user=${replication_user} password=''${replication_pass}'' host=${db_host} port=5432 sslmode=prefer sslcompression=0 krbsrvname=postgres target_session_attrs=any'
trigger_file = 'trigger-failover'
restore_command = 'test ! -f ${ARCHIVE_FROM_DIR}/%f || cp -v ${ARCHIVE_FROM_DIR}/%f %p'
EOD

chmod 0660 ${PGDATA}/recovery.conf
