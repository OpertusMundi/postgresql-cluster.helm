#!/bin/sh
set -e -u
#set -x

test -d "${PGDATA}"

replication_user=${REPLICATION_USER}
replication_password_file=${REPLICATION_PASSWORD_FILE}
master_host=${MASTER_HOST:-localhost}

replication_password="$(cat ${replication_password_file})"

# Prepare credentials

pgpass_file=~/.pgpass
touch ${pgpass_file}
chmod u=rw,g=,o= ${pgpass_file}

pgpass_line=$(echo -n "${master_host}:5432:*:${replication_user}:${replication_password}")
grep -qF -e "${pgpass_line}" ${pgpass_file} || echo "${pgpass_line}" >> ${pgpass_file}

# Take basebackup

if [ -n "$(ls -A ${PGDATA})" ]; then
    echo "The target directory (${PGDATA}) is not empty. Skipping basebackup." 1>&2
    if ! [ -f "${PGDATA}/PG_VERSION" ]; then
        echo "The target directory (${PGDATA}) is not a data directory! (PG_VERSION not found)" 1>&2
        exit 1
    fi
    if [ -f "${PGDATA}/recovery.done" ]; then
        echo "The data directory has finished recovery!" 1>&2
        exit 1
    fi
else
    # data directory is empty
    echo "Taking a basebackup from ${master_host}..."  1>&2
    pg_basebackup -v --checkpoint=fast -h ${master_host} -U ${replication_user} -D ${PGDATA}
fi
