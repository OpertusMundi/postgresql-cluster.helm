#!/bin/sh
set -e -u
set -x

output_dir=
input_dir=
key_file=${PGPOOLKEYFILE:-}

while getopts ":i:o:" opt; do
    case $opt in
        o)
            output_dir=${OPTARG}
            ;;
        i)
            input_dir=${OPTARG}
            ;;
        k)
            key_file=${OPTARG}
            ;;
        :)
            echo "option ${OPTARG} requires an argument" && exit 1
            ;;
        ?)
            echo "invalid option: ${OPTARG}" && exit 1
            ;;
    esac
done


[ -n "${input_dir}" ]
user_passwords_dir=${input_dir%%/}
[ -d ${user_passwords_dir} ]

user_passwords_file=$(mktemp -t user-passwords-XXXXXX)
for f in ${user_passwords_dir}/*
do
    echo "$(basename ${f}):$(cat ${f})"; 
done > ${user_passwords_file}

# if key file missing, generate from /dev/urandom
if [ -z "${key_file}" ] || [ ! -f ${key_file} ] ; then
    key_file=$(mktemp -t pgpool-key-XXXXXX)
    chmod -v 0600 ${key_file}
    dd 'if=/dev/urandom' 'count=1' 'bs=15' | base64 > ${key_file}
fi

pg_enc -k ${key_file} -m -i ${user_passwords_file}

if [ -n "${output_dir}" ] && [ -d ${output_dir} ]; then 
    cp -vn ${key_file} ${output_dir}/key
    cp -vn /etc/pgpool/pool_passwd ${output_dir}/pool_passwd
    chmod -v 0600 ${output_dir}/*
fi
