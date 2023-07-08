#!/bin/bash
set -e
#set -x

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

function _gen_user_passwords_file()
{
    # Generate pairs of user:password
    user_passwords_dir=${USER_PASSWORDS_DIR%/}
    for f in ${user_passwords_dir}/*
    do
        echo "$(basename ${f}):$(cat ${f})"; 
    done
}

#
# Check environment
#

test -d "${PGPOOL_CONFIG_DIR}"

if [ ! -f "${PGPOOL_ADMIN_PASSWORD_FILE}" ]; then
    echo "The file with the admin password for PgPool (PGPOOL_ADMIN_PASSWORD_FILE) is missing!" 1>&2
    exit 1
fi

auth_methods=( "md5" "scram-sha-256" )
grep -w -q -F -e "${AUTH_METHOD}" < <(echo "${auth_methods[*]}")

if [ "${AUTH_METHOD}" == 'scram-sha-256' ] && [ ! -f "${PGPOOLKEYFILE}" ]; then
    echo "PGPOOLKEYFILE file (${PGPOOLKEYFILE}) is missing!" 1>&2
    exit 1
fi

#
# Generate credentials for management interface (pcp.conf)
#

pgpool_admin_password=$(cat ${PGPOOL_ADMIN_PASSWORD_FILE})

echo "${PGPOOL_ADMIN_USER}:"$(pg_md5 "${pgpool_admin_password}") >> /var/lib/pgpool/pcp.conf

echo "*:*:${PGPOOL_ADMIN_USER}:${pgpool_admin_password}" | tee ~/.pcppass > ~postgres/.pcppass
chmod u=rw,g=,o= ~/.pcppass
chown postgres:postgres ~postgres/.pcppass && chmod u=rw,g=,o= ~postgres/.pcppass


#
# Generate entry for pool_hba.conf depending on auth method
#

echo "hostssl all all all ${AUTH_METHOD}" >> ${POOL_HBA_FILE}

#
# Generate pool_passwd from directory of user credentials
#

if [ ! -s ${POOL_PASSWD_FILE} ]; then
    echo "Generating pool_passwd file at ${POOL_PASSWD_FILE}" 1>&2
    touch ${POOL_PASSWD_FILE} 
    chown root:postgres ${POOL_PASSWD_FILE} && chmod g=r,o= ${POOL_PASSWD_FILE}
    if [ -d "${USER_PASSWORDS_DIR}" ]; then
        user_passwords_file=$(mktemp -t user-passwords-XXXXXX)
        _gen_user_passwords_file > ${user_passwords_file}
        if [ "${AUTH_METHOD}" == "scram-sha-256" ]; then
            pg_enc -m -i ${user_passwords_file}
        else
            pg_md5 -m -i ${user_passwords_file}
        fi
    fi
fi

#
# Generate pgpool.conf
#

touch ${PGPOOL_CONFIG_DIR}/pgpool.conf
chmod g=r,o= ${PGPOOL_CONFIG_DIR}/pgpool.conf && chown root:postgres ${PGPOOL_CONFIG_DIR}/pgpool.conf

backend_configuration_escaped=$(_gen_configuration_for_backend | sed ':a;N;$!ba;s/\n/\\n/g')
test -n "${backend_configuration_escaped}"

monitor_password="$(cat ${MONITOR_PASSWORD_FILE})"

sed \
    -e "s/^load_balance_mode[[:blank:]]*=[[:blank:]]*\(on\|off\)/load_balance_mode = ${LOAD_BALANCE:-on}/" \
    -e "s/\${NUM_PROCS}/${NUM_PROCS:-32}/" \
    -e "s/\${POOL_SIZE}/${POOL_SIZE:-4}/" \
    -e "s/\${CHILD_LIFE_TIME}/${CHILD_LIFE_TIME:-5min}/" \
    -e "s/\${CLIENT_IDLE_LIMIT}/${CLIENT_IDLE_LIMIT:-0}/" \
    -e "s~\${POOL_PASSWD_FILE}~${POOL_PASSWD_FILE}~" \
    -e "s~^ssl[[:blank:]]*=[[:blank:]]*off~ssl = on~" \
    -e "s~\${TLS_KEY_FILE}~${TLS_KEY_FILE}~" \
    -e "s~\${TLS_CERT_FILE}~${TLS_CERT_FILE}~" \
    -e "s/\${MONITOR_USER}/${MONITOR_USER}/" \
    -e "s/\${MONITOR_PASSWORD}/${monitor_password}/" \
    -e "s/\${HEALTH_CHECK_PERIOD}/${HEALTH_CHECK_PERIOD}/" \
    -e "s/\${HEALTH_CHECK_MAX_RETRIES}/${HEALTH_CHECK_MAX_RETRIES}/" \
    -e "s/\${HEALTH_CHECK_RETRY_DELAY}/${HEALTH_CHECK_RETRY_DELAY}/" \
    -e "/^#[[:blank:]]\+[-][[:blank:]]\+Backend/a "'\\n'"${backend_configuration_escaped}" \
    ${PGPOOL_CONFIG_DIR}/pgpool.conf.template > ${PGPOOL_CONFIG_DIR}/pgpool.conf

#
# Start
#

exec su-exec postgres $@
