#!/usr/bin/env bash

#? Description:
#?   Build the Docker image and run an ssmanager container for testing.
#?
#?   Without any option, it builds the image and runs an ssmanager container in the
#?   foreground with an SS-2022 cipher.
#?
#? Usage:
#?   docker-build-and-run.sh [-P] [-m MGT_PORT] [-p SS_PORTS] [-e ENCRYPT]
#?   docker-build-and-run.sh [-h]
#?
#? Options:
#?   [-P]
#?
#?   Enable to fetch the env `DOCKER_BUILD_ARGS_PROXY` and pass to docker build command.
#?   If the env `DOCKER_BUILD_ARGS_PROXY` is not set or empty, exit with error.
#?
#?   [-m MGT_PORT]
#?
#?   Specify the management port for the shadowsocks manager.
#?   Default is 6001.
#?
#?   [-p SS_PORTS]
#?
#?   Specify the shadowsocks ports to be exposed.
#?   Default is 8381-8385.
#?
#?   [-e ENCRYPT]
#?
#?   Specify the encryption method for shadowsocks.
#?   Default is 2022-blake3-aes-256-gcm.
#?
#?   [-h]
#?
#?   This help.
#?
#? Environment:
#?   The following environment variables are used by this script conditionally:
#?
#?   - DOCKER_BUILD_ARGS_PROXY="--build-arg http_proxy=http://host.docker.internal:1086 --build-arg https_proxy=http://host.docker.internal:1086 --build-arg all_proxy=socks5://host.docker.internal:1086"
#?
#?     Optional, default is unset.
#?     Set the proxy for the Docker build. Please replace the proxy port with your actual port.
#?

# exit on any error
set -e -o pipefail

function usage () {
    awk '/^#\?/ {sub("^[ ]*#\\?[ ]?", ""); print}' "$0" \
        | awk '{gsub(/^[^ ]+.*/, "\033[1m&\033[0m"); print}'
}

function check-vars () {
    declare var ret=0
    for var in "$@"; do
        if [[ -z ${!var} ]]; then
            echo "FATAL: environment variable $var is not set or empty." >&2
            (( ret++ ))
        fi
    done
    return $ret
}

function main () {
    declare proxy_flag=0 \
            mgt_port=6001 ss_ports=8381-8385 encrypt=2022-blake3-aes-256-gcm \
            OPTIND OPTARG opt

    while getopts Pm:p:e:h opt; do
        case $opt in
            P)
                proxy_flag=1
                ;;
            m)
                mgt_port=$OPTARG
                ;;
            p)
                ss_ports=$OPTARG
                ;;
            e)
                encrypt=$OPTARG
                ;;
            *)
                usage
                return 255
                ;;
        esac
    done

    check-vars mgt_port ss_ports encrypt

    declare build_opts=() \
            run_opts=(--restart=always) \
            run_port_opts=(-p "$mgt_port:$mgt_port/UDP" -p "$ss_ports:$ss_ports" -p "$ss_ports:$ss_ports/UDP") \
            run_cmd_opts=( ssmanager
                --manager-address "0.0.0.0:$mgt_port"
                -m "$encrypt" -s 0.0.0.0 -U
            )

    if [[ $proxy_flag -eq 1 ]]; then
        check-vars DOCKER_BUILD_ARGS_PROXY
        # do not quote it
        # shellcheck disable=SC2206
        build_opts+=($DOCKER_BUILD_ARGS_PROXY)
    fi

    declare image_name=alexzhangs/shadowsocks-rust

    declare script_dir
    script_dir=$(dirname "$0")

    declare -a BUILD_OPTS RUN_OPTS

    function __build_and_run__ () {
        # build the image
        echo ""
        echo "INFO: docker build ${BUILD_OPTS[*]}"
        docker build "${BUILD_OPTS[@]}"

        # run the container
        echo ""
        echo "INFO: docker run ${RUN_OPTS[*]}"
        docker run "${RUN_OPTS[@]}" || :
    }

    declare image_tag image container
    image_tag=dev-$(date +%Y%m%d-%H%M)
    image="$image_name:$image_tag"
    container="ss-rust-$image_tag"
    BUILD_OPTS=( "${build_opts[@]}" -t "$image" -f "$script_dir/Dockerfile" "$script_dir" )
    RUN_OPTS=( "${run_opts[@]}" "${run_port_opts[@]}" --name "$container" "$image" "${run_cmd_opts[@]}" )

    __build_and_run__
}

main "$@"

exit
