#!/bin/sh
set -e -u
#set -x

test -n "${PGPASSFILE}" && test ! -f "${PGPASSFILE}"

touch ${PGPASSFILE}
chmod u=rw,g=,o= ${PGPASSFILE}

master_host=${MASTER_HOST}

postgres_password_file=${POSTGRES_PASSWORD_FILE}
postgres_password="$(cat ${postgres_password_file})"

replication_user=${REPLICATION_USER}
replication_password_file=${REPLICATION_PASSWORD_FILE}
replication_password="$(cat ${replication_password_file})"

{
    echo "${master_host}:5432:*:postgres:${postgres_password}";
    echo "${master_host}:5432:*:${replication_user}:${replication_password}";
} >> ${PGPASSFILE}

