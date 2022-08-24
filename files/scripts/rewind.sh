#!/bin/sh
set -e -u
set -x

test -d "${PGDATA}"

# Rewind

pg_rewind -P --target-pgdata ${PGDATA} --source-server="user=postgres host=${MASTER_HOST}"
