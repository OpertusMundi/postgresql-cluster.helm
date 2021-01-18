#!/bin/bash 
set -e

[ -n "${USER_PASSWORDS_DIR}" ] || exit 0;
if [ ! -d "${USER_PASSWORDS_DIR}" ]; then
    echo "USER_PASSWORDS_DIR is not a directory: ${USER_PASSWORDS_DIR}" 1>&2
    exit 1;
fi

quote='$q$'
for f in $(ls ${USER_PASSWORDS_DIR}); do
    user=${f}
    pass=$(cat ${USER_PASSWORDS_DIR}/${f})
    echo "CREATE USER ${user} WITH PASSWORD ${quote}${pass}${quote} LOGIN;" |\
        psql -v ON_ERROR_STOP=1 -U "${POSTGRES_USER}" -d "${POSTGRES_DB}"
done
