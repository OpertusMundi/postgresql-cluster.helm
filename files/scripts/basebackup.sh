#!/bin/sh
set -e
#set -x

test -d "${PGDATA}"

if [ -n "$(ls -A ${PGDATA})" ]; then
    echo "The target directory (${PGDATA}) is not empty. Nothing to do." 1>&2
    if ! [ -f "${PGDATA}/PG_VERSION" ]; then
        echo "The target directory (${PGDATA}) does not seem like a PostgreSQL data directory!" 1>&2
        exit 1
    fi
    if ! [ -f "${PGDATA}/recovery.conf" ]; then
        echo "The data directory does not contain recovery.conf!" 1>&2
        exit 1
    fi
    exit 0
fi

# Read command line

archive_dir=/var/backups/postgresql/archive
replication_user=replicator
replication_password_file=replicator-password

options=$(getopt -u -o a:u:p: -l archive-dir:,user:,password-file: -- "${@}") || exit 1;
set -- ${options}

while [ ${#} -gt "0" ]; do
    case ${1} in
    --user) 
      replication_user="${2}"; shift;;
    --password-file)
      replication_password_file="${2}"; shift;;
    --archive-dir) 
      archive_dir="${2}"; shift;;
    (--) 
      shift; break;;
    (-*) 
      echo "${0}: error - unrecognized option ${1}" 1>&2; 
      exit 1;;
    (*) 
      break;;
    esac
    # Fetch next argument
    shift
done

master_host=${1:-localhost}
replication_password="$(cat ${replication_password_file})"

# Prepare credentials

pgpass_file=~/.pgpass
touch ${pgpass_file}
chmod 0600 ${pgpass_file}

pgpass_line=$(echo -n "${master_host}:5432:*:${replication_user}:${replication_password}")
grep -qF -e "${pgpass_line}" ${pgpass_file} || echo "${pgpass_line}" >> ${pgpass_file}

# Take basebackup

pg_basebackup -v --checkpoint=fast -h ${master_host} -U ${replication_user} -D ${PGDATA}

# Generate recovery.conf

cat <<EOD > "${PGDATA}/recovery.conf"
standby_mode = 'on'
primary_conninfo = 'user=${replication_user} password=''${replication_password}'' host=${master_host} port=5432 sslmode=prefer sslcompression=0 krbsrvname=postgres target_session_attrs=any'
trigger_file = 'trigger-failover'
restore_command = 'test ! -f ${archive_dir}/%f || cp -v ${archive_dir}/%f %p'
EOD

chmod 0660 "${PGDATA}/recovery.conf"
