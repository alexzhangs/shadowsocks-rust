#!/usr/bin/env bash

#? Description:
#?   This script is the entry point for the Docker container.
#?
#?   It is intentionally a thin wrapper: it simply execs the command passed to it
#?   (defaulting to `ssmanager`, see the Dockerfile CMD). Unlike the
#?   shadowsocks-libev-v2ray image, no TLS certificate / v2ray-plugin bootstrap is
#?   performed here -- the value of Shadowsocks-2022 is that it needs no plugin.
#?
#? Usage:
#?   docker-entrypoint.sh <ssmanager|ssserver|sslocal|ssservice|ssurl|...> [OPTIONS]
#?
#? Options:
#?   <ssmanager|ssserver|sslocal|ssservice|ssurl|...>
#?
#?   Specify the service or tool to start.
#?
#?   [OPTIONS]
#?
#?   The options are passed to the service as is, no more, no less.
#?

# exit on any error
set -e -o pipefail

function usage () {
    awk '/^#\?/ {sub("^[ ]*#\\?[ ]?", ""); print}' "$0" \
        | awk '{gsub(/^[^ ]+.*/, "\033[1m&\033[0m"); print}'
}

function main () {
    if [[ $# -eq 0 ]]; then
        usage
        exit 255
    fi

    exec "$@"
}

main "$@"

exit
