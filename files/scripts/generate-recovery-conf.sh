#!/bin/sh
set -eu
set -x

test -d "${PGDATA}"

archive_dir=${ARCHIVE_MASTER_DIR}
replication_user=${REPLICATION_USER}
replication_password_file=${REPLICATION_PASSWORD_FILE}
master_host=${MASTER_HOST}

replication_password="$(cat ${replication_password_file})"

test -d "${archive_dir}"

application_name=${HOSTNAME//-/_}

force=
while [ ${#} -gt "0" ]; do
    case ${1} in
        --force)
            force=t
            ;;
    esac
    shift;
done

if ! [ -f "${PGDATA}/recovery.conf" ] || [ ${force} == "t" ] ; then
    echo "Generating recovery.conf..." 1>&2
    cat <<-EOD > "${PGDATA}/recovery.conf"
	standby_mode='on'
	primary_conninfo='user=${replication_user} password=''${replication_password}'' host=${master_host} port=5432 application_name=${application_name} sslmode=prefer sslcompression=0'
	trigger_file='failover-trigger'
	recovery_target_timeline=latest
	restore_command='test ! -f ${archive_dir}/%f || cp -v ${archive_dir}/%f %p'
	EOD
    chmod u=rw,g=rw,o= "${PGDATA}/recovery.conf"
fi

