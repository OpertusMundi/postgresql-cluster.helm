#!/bin/bash
set -e
#set -x

pcp_socket_dir=/var/run/pgpool/
pcp_opts="--host ${pcp_socket_dir} --username pgpool --no-password"

n=$(pcp_node_count ${pcp_opts})
test $n -gt "0"

# find primary node (for streaming replication) and check status is not down
# see docs on fields at https://www.pgpool.net/docs/41/en/html/pcp-node-info.html
for i in $(seq 0 $((n - 1))); do
    # note: mimic Bash arrays by using positional parameters
    # https://unix.stackexchange.com/questions/384614/how-to-port-to-bash-style-arrays-to-ash
    set -- $(pcp_node_info ${pcp_opts} ${i})
    hostname=${1}
    status_text=${5}
    backend_role=${6}
    case "${backend_role}" in
      primary)
        if [[ "${status_text}" == 'up' || "${status_text}" == 'waiting' ]]; then
            # the primary node is healthy
            exit 0
        fi
        ;;
      standby)
        continue
        ;;
      *)
        echo "Did not expect this role (${backend_role}) for node ${hostname}" 1>&2
        exit 1
        ;;
    esac
done

# no primary node (degenerated cluster), or primary node is down
exit 1
