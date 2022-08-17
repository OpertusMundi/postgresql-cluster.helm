#!/bin/sh
set -e -u
set -x

test -d "${PGDATA}"

postgres_password_file=${POSTGRES_PASSWORD_FILE}
master_host=${MASTER_HOST:-localhost}

postgres_password="$(cat ${postgres_password_file})"

# Prepare credentials

pgpass_file=~/.pgpass
touch ${pgpass_file}
chmod u=rw,g=,o= ${pgpass_file}

pgpass_line=$(echo -n "${master_host}:5432:*:postgres:${postgres_password}")
grep -qF -e "${pgpass_line}" ${pgpass_file} || echo "${pgpass_line}" >> ${pgpass_file}

# Rewind

pg_rewind -P --target-pgdata ${PGDATA} --source-server="user=postgres host=${master_host}"
