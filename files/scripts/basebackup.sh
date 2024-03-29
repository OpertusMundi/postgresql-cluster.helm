#!/bin/sh
set -e -u
#set -x

test -d "${PGDATA}"

if [ -n "$(ls -A ${PGDATA})" ]; then
    echo "The target directory (${PGDATA}) is not empty. Skipping basebackup." 1>&2
    if ! [ -f "${PGDATA}/PG_VERSION" ]; then
        echo "The target directory (${PGDATA}) is not a data directory! (PG_VERSION not found)" 1>&2
        exit 1
    fi
else
    # data directory is empty: take basebackup
    echo "Taking a basebackup from ${MASTER_HOST}..."  1>&2
    pg_basebackup -v --checkpoint=fast -h ${MASTER_HOST} -U ${REPLICATION_USER} -D ${PGDATA}
fi
