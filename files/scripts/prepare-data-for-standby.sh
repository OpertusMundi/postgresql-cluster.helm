#!/bin/sh
set -e -u
set -x

test -d "${PGDATA}"

# Prepare data dir: rewind or basebackup

if [ -n "$(ls -A ${PGDATA})" ]; then
    # data directory is not empty
    if ! [ -f "${PGDATA}/PG_VERSION" ]; then
        echo "The target directory (${PGDATA}) is not a data directory! (PG_VERSION not found)" 1>&2
        exit 1
    fi
    # note: if target and source are already on the same timeline, rewind does nothing
    if [ "${REWIND_DATA:-false}" == "true" ]; then
      pg_rewind -P --target-pgdata ${PGDATA} --source-server="user=postgres host=${MASTER_HOST}"
    fi
else
    # data directory is empty: take basebackup
    echo "Taking a basebackup from ${MASTER_HOST}..."  1>&2
    pg_basebackup -v --checkpoint=fast -h ${MASTER_HOST} -U ${REPLICATION_USER} -D ${PGDATA}
fi

touch ${PGDATA}/standby.signal
