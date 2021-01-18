#!/bin/sh
set -e
#set -x

timeout="30"
interval="2"

options=$(getopt -u -o t:i: -l timeout:,interval: -- "${@}") || exit 1;
set -- ${options}

while [ ${#} -gt "0" ]; do
    case ${1} in
    --interval) 
      interval="${2}"; shift;;
    --timeout)
      timeout="${2}"; shift;;
    (--) 
      shift; break;;
    (-*) 
      echo "${0}: error - unrecognized option ${1}" 1>&2; 
      exit 1;;
    (*) 
      break;;
    esac
    shift
done

# Wait until all hosts are pinged successfully

n=$((${timeout} / ${interval}))
for host in ${@}; do
    while ! ping -q -c 1 ${host}; do
       sleep ${interval} && n=$((n - 1))
       test ${n} -ne "0" 
    done
done
