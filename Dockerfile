# Description:
#   This Dockerfile builds a Shadowsocks manager (ssmanager) Docker image based on
#   shadowsocks-rust. Unlike shadowsocks-libev, shadowsocks-rust supports the
#   Shadowsocks-2022 (SIP022 AEAD-2022) ciphers, e.g. 2022-blake3-aes-256-gcm.
#
#   The image ships the full shadowsocks-rust toolset:
#     - ssmanager  : multi-user manager, speaks the same UDP Manager API as
#                    shadowsocks-libev's ss-manager (add/remove/list/ping).
#     - ssserver   : standalone server.
#     - sslocal    : local client (handy for smoke tests).
#     - ssservice  : utilities, incl. `ssservice genkey -m <method>` to generate
#                    a valid SS-2022 PSK (Base64 key of the cipher's key size).
#     - ssurl      : ss:// URL encode/decode.
#
#   It is a drop-in companion to alexzhangs/shadowsocks-manager and a sibling of
#   alexzhangs/shadowsocks-libev-v2ray: the Django portal controls it over the
#   identical UDP Manager API, so the only thing that changes versus the libev
#   image is the server edition (rust) and the available ciphers (SS-2022).
#
# Expose:
#   - 6001/udp: default Manager API port (override via the run command).
#
# Build:
#   docker build -t alexzhangs/shadowsocks-rust .
#   docker build --platform linux/amd64 -t alexzhangs/shadowsocks-rust .
#
# Run:
#
#   ### Start a Shadowsocks manager service with an SS-2022 cipher (no live port): ###
#
#   MGR_PORT=6001 SS_PORTS=8381-8385 ENCRYPT=2022-blake3-aes-256-gcm
#
#   docker run --restart=always -d -p $MGR_PORT:$MGR_PORT/UDP \
#     -p $SS_PORTS:$SS_PORTS -p $SS_PORTS:$SS_PORTS/UDP \
#     --name ss-manager-rust alexzhangs/shadowsocks-rust \
#     ssmanager --manager-address 0.0.0.0:$MGR_PORT -m $ENCRYPT -s 0.0.0.0 -U
#
#   Then add a user (port) over the Manager API. The password MUST be a Base64
#   PSK of the cipher's key size for SS-2022 ciphers (use `ssservice genkey`):
#
#   PSK=$(docker exec ss-manager-rust ssservice genkey -m $ENCRYPT)
#   echo "add: {\"server_port\":8381,\"password\":\"$PSK\"}" | nc -u -w1 127.0.0.1 $MGR_PORT
#
#
#   ### Start a standalone single-port SS-2022 server: ###
#
#   SS_PORT=8388 ENCRYPT=2022-blake3-aes-256-gcm
#   PSK=$(docker run --rm alexzhangs/shadowsocks-rust ssservice genkey -m $ENCRYPT)
#
#   docker run --restart=always -d -p $SS_PORT:$SS_PORT -p $SS_PORT:$SS_PORT/udp \
#     --name ss-server-rust alexzhangs/shadowsocks-rust \
#     ssserver -s 0.0.0.0:$SS_PORT -m $ENCRYPT -k "$PSK" -U
#
# For more information, please refer to the project repository:
#   https://github.com/alexzhangs/shadowsocks-rust
#

# To enable proxy at build time, use:
# docker build --build-arg https_proxy=http://host.docker.internal:$PROXY_HTTP_PORT_ON_HOST ...
ARG http_proxy https_proxy all_proxy

# Pinned by digest for reproducible builds (alpine:latest as of 2026-06-15).
# Bump deliberately (e.g. via Dependabot/Renovate Docker digest updates).
FROM alpine@sha256:a2d49ea686c2adfe3c992e47dc3b5e7fa6e6b5055609400dc2acaeb241c829f4

# shadowsocks-rust release to install. The musl static builds are used so the
# binaries run on the Alpine (musl libc) base without extra runtime libraries.
# Pinned to a release tag with per-arch sha256 checksums; bump deliberately.
ARG SS_VERSION=1.24.0
ARG SS_SHA256_X86_64=0d84f5f350ec99396867d718f146fc3810975b2a7cd06192f158d96bdef460e7
ARG SS_SHA256_AARCH64=e00b6551f40bb2d61adb2503909e0df6550c022372c812f3f34350510797ef2f

# - bash            : used by docker-entrypoint.sh
# - ca-certificates : TLS roots for outbound connections
# - curl, xz        : download and extract the shadowsocks-rust release tarball
RUN apk --no-cache add bash ca-certificates curl xz

# Download, verify, and install the shadowsocks-rust binaries.
RUN <<EOF
    set -ex
    ARCH=$(uname -m)
    case ${ARCH} in
        x86_64)
            RUST_ARCH=x86_64
            SHA256=${SS_SHA256_X86_64}
            ;;
        aarch64)
            RUST_ARCH=aarch64
            SHA256=${SS_SHA256_AARCH64}
            ;;
        *)
            echo "${ARCH}: Unsupported architecture"
            exit 1
            ;;
    esac
    TARBALL="shadowsocks-v${SS_VERSION}.${RUST_ARCH}-unknown-linux-musl.tar.xz"
    URL="https://github.com/shadowsocks/shadowsocks-rust/releases/download/v${SS_VERSION}/${TARBALL}"
    curl -fsSL -o "/tmp/${TARBALL}" "${URL}"
    # Verify the official checksum before trusting the tarball.
    echo "${SHA256}  /tmp/${TARBALL}" | sha256sum -c -
    # The tarball contains the binaries flat at its root.
    tar -C /usr/local/bin -xJf "/tmp/${TARBALL}"
    chmod +x /usr/local/bin/sslocal /usr/local/bin/ssserver /usr/local/bin/ssmanager \
        /usr/local/bin/ssservice /usr/local/bin/ssurl
    rm -f "/tmp/${TARBALL}"
EOF

# Verify that the toolset is installed.
RUN ssmanager --version && ssserver --version && ssservice --version

# Set work directory
WORKDIR /shadowsocks-rust

# Copy the current directory contents at local into the container
COPY . .

RUN chmod +x docker-entrypoint.sh

# Default Manager API port (UDP). Override via the run command as needed.
EXPOSE 6001/udp

ENTRYPOINT [ "./docker-entrypoint.sh" ]

CMD [ "ssmanager", "--manager-address", "0.0.0.0:6001", "-m", "2022-blake3-aes-256-gcm", "-s", "0.0.0.0", "-U" ]
