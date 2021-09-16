#!/bin/bash
set -e

function _gen_configuration_for_backend() 
{    
    i=0;
    while true; do
        
        host_var_name="BACKEND_${i}_HOST"
        host=${!host_var_name}
        test -n "${host}" || break;
        echo "backend_hostname${i} = ${host}"
        
        port_var_name="BACKEND_${i}_PORT"
        port=${!port_var_name}
        echo "backend_port${i} = ${port:-5432}"
        
        weight_var_name="BACKEND_${i}_WEIGHT"
        weight=${!weight_var_name}
        echo "backend_weight${i} = ${weight:-1}"

        name_var_name="BACKEND_${i}_NAME"
        name=${!name_var_name}
        test -n "${name}" || name="server$((i+1))"
        echo "backend_application_name${i} = ${name}"

        echo "backend_flag${i} = 'ALLOW_TO_FAILOVER'"
    
        # Move to next
        i=$((i+1))
    done
}

# Check environment

if [ ! -f "${PGPOOL_ADMIN_PASSWORD_FILE}" ]; then
    echo "The file with the admin password for PgPool (PGPOOL_ADMIN_PASSWORD_FILE) is missing!" 1>&2
    exit 1
fi

# Generate credentials for management interface (pcp.conf)

pgpool_admin_password=$(cat ${PGPOOL_ADMIN_PASSWORD_FILE})

echo "${PGPOOL_ADMIN_USER}:"$(pg_md5 "${pgpool_admin_password}") >> /var/lib/pgpool/pcp.conf

echo "*:*:${PGPOOL_ADMIN_USER}:${pgpool_admin_password}" > ~/.pcppass
chmod u=rw,g=,o= ~/.pcppass

#
# Generate pool_passwd from directory of user credentials
#

if [ ! -f ${POOL_PASSWD_FILE} ]; then
    touch ${POOL_PASSWD_FILE} 
    chown root:postgres ${POOL_PASSWD_FILE} && chmod g=r,o= ${POOL_PASSWD_FILE}
    if [ -d "${USER_PASSWORDS_DIR}" ]; then
        for username in  $(ls -1 ${USER_PASSWORDS_DIR}); do
            pg_md5 --md5auth --username ${username} "$(cat ${USER_PASSWORDS_DIR%/}/${username})"
        done
    fi
fi

#
# Generate pgpool.conf
#

touch /etc/pgpool/pgpool.conf
chmod g=r,o= /etc/pgpool/pgpool.conf && chown root:postgres /etc/pgpool/pgpool.conf

backend_configuration_escaped=$(_gen_configuration_for_backend | sed ':a;N;$!ba;s/\n/\\n/g')
test -n "${backend_configuration_escaped}"

monitor_password="$(cat ${MONITOR_PASSWORD_FILE})"

sed \
    -e "s/^load_balance_mode[[:blank:]]*=[[:blank:]]*\(on\|off\)/load_balance_mode = ${LOAD_BALANCE:-on}/" \
    -e "s/\${NUM_PROCS}/${NUM_PROCS:-32}/" \
    -e "s/\${POOL_SIZE}/${POOL_SIZE:-4}/" \
    -e "s~\${POOL_PASSWD_FILE}~${POOL_PASSWD_FILE}~" \
    -e "s~^ssl[[:blank:]]*=[[:blank:]]*off~ssl = on~" \
    -e "s~\${TLS_KEY_FILE}~${TLS_KEY_FILE}~" \
    -e "s~\${TLS_CERT_FILE}~${TLS_CERT_FILE}~" \
    -e "s/\${MONITOR_USER}/${MONITOR_USER}/" \
    -e "s/\${MONITOR_PASSWORD}/${monitor_password}/" \
    -e "/^#[[:blank:]]\+[-][[:blank:]]\+Backend/a "'\\n'"${backend_configuration_escaped}" \
    /etc/pgpool/pgpool.conf.template > /etc/pgpool/pgpool.conf

#
# Start
#

exec su-exec postgres $@
