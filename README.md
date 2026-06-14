[![License](https://img.shields.io/github/license/alexzhangs/shadowsocks-rust.svg?style=flat-square)](https://github.com/alexzhangs/shadowsocks-rust/)
[![GitHub last commit](https://img.shields.io/github/last-commit/alexzhangs/shadowsocks-rust.svg?style=flat-square)](https://github.com/alexzhangs/shadowsocks-rust/commits/main)
[![GitHub issues](https://img.shields.io/github/issues/alexzhangs/shadowsocks-rust.svg?style=flat-square)](https://github.com/alexzhangs/shadowsocks-rust/issues)
[![GitHub pull requests](https://img.shields.io/github/issues-pr/alexzhangs/shadowsocks-rust.svg?style=flat-square)](https://github.com/alexzhangs/shadowsocks-rust/pulls)
[![GitHub tag](https://img.shields.io/github/v/tag/alexzhangs/shadowsocks-rust?sort=date)](https://github.com/alexzhangs/shadowsocks-rust/tags)

[![GitHub Actions - CI Docker Build and Push](https://github.com/alexzhangs/shadowsocks-rust/actions/workflows/ci-docker.yml/badge.svg)](https://github.com/alexzhangs/shadowsocks-rust/actions/workflows/ci-docker.yml)
[![Docker Image Version](https://img.shields.io/docker/v/alexzhangs/shadowsocks-rust?label=docker%20image)](https://hub.docker.com/r/alexzhangs/shadowsocks-rust)

# shadowsocks-rust

A [shadowsocks-rust](https://github.com/shadowsocks/shadowsocks-rust) `ssmanager` Docker
image that adds **Shadowsocks-2022 (SIP022 AEAD-2022)** support to the
[shadowsocks-manager](https://github.com/alexzhangs/shadowsocks-manager) ecosystem.

It is a sibling of [shadowsocks-libev-v2ray](https://github.com/alexzhangs/shadowsocks-libev-v2ray):
the Django portal controls both over the **identical UDP Manager API**
(`add` / `remove` / `list` / `ping`), so swapping from libev to rust is just a change of
*server edition* — and it unlocks the SS-2022 ciphers that shadowsocks-libev does not implement.

## Why a separate image?

`shadowsocks-libev` has no SS-2022 ciphers. `shadowsocks-rust` does, **and** its `ssmanager`
speaks the same UDP multi-user Manager API as libev's `ss-manager`. So shadowsocks-manager can
drive an SS-2022 node with no change to its control plane — only the cipher and the server
edition differ.

SS-2022 (e.g. `2022-blake3-aes-256-gcm`) was the most GFW-resilient option in a multi-protocol
shootout from inside China, with no plugin required.

## What's in the image

The full shadowsocks-rust toolset (musl static builds on Alpine):

- `ssmanager` — multi-user manager (the default `CMD`).
- `ssserver` — standalone server.
- `sslocal` — local client (useful for smoke tests).
- `ssservice` — utilities, incl. `ssservice genkey -m <method>` to generate a valid SS-2022 PSK.
- `ssurl` — `ss://` URL encode/decode.

## Supported SS-2022 ciphers

| Method | Key size | Password (PSK) |
|---|---|---|
| `2022-blake3-aes-128-gcm` | 16 bytes | Base64 of 16 random bytes (24 chars) |
| `2022-blake3-aes-256-gcm` | 32 bytes | Base64 of 32 random bytes (44 chars) |
| `2022-blake3-chacha20-poly1305` | 32 bytes | Base64 of 32 random bytes (44 chars) |

> For SS-2022 ciphers the password **must** be a Base64-encoded key of exactly the cipher's key
> size — arbitrary passwords are rejected by the server. Generate one with:
>
> ```sh
> docker run --rm alexzhangs/shadowsocks-rust ssservice genkey -m 2022-blake3-aes-256-gcm
> ```
>
> All legacy AEAD/stream ciphers supported by shadowsocks-rust (e.g. `aes-256-gcm`,
> `chacha20-ietf-poly1305`) also work, with arbitrary passwords.

## Usage

Start a Shadowsocks manager service with an SS-2022 cipher (no live port until users are added):

```sh
MGR_PORT=6001 SS_PORTS=8381-8385 ENCRYPT=2022-blake3-aes-256-gcm

docker run --restart=always -d \
  -p $MGR_PORT:$MGR_PORT/UDP \
  -p $SS_PORTS:$SS_PORTS -p $SS_PORTS:$SS_PORTS/UDP \
  --name ss-manager-rust alexzhangs/shadowsocks-rust \
  ssmanager --manager-address 0.0.0.0:$MGR_PORT -m $ENCRYPT -s 0.0.0.0 -U
```

Add a user (port) over the Manager API — the password is a Base64 PSK for SS-2022:

```sh
PSK=$(docker exec ss-manager-rust ssservice genkey -m 2022-blake3-aes-256-gcm)
echo "add: {\"server_port\":8381,\"password\":\"$PSK\"}" | nc -u -w1 127.0.0.1 6001
echo "list" | nc -u -w1 127.0.0.1 6001
echo "remove: {\"server_port\":8381}" | nc -u -w1 127.0.0.1 6001
```

`-U` enables `TCP_AND_UDP` relay; `-s 0.0.0.0` is the default bind for spawned servers; `-m` is
the default cipher applied to added ports.

### With shadowsocks-manager

In the portal, create a Node, then a Shadowsocks Manager on it with:

- **Server edition**: `rust`
- **Encrypt**: an SS-2022 method, e.g. `2022-blake3-aes-256-gcm`

shadowsocks-manager generates conforming PSKs for accounts on SS-2022 nodes automatically.

## Manager API command compatibility

| Command | shadowsocks-libev `ss-manager` | shadowsocks-rust `ssmanager` |
|---|---|---|
| `add` | yes | yes |
| `remove` | yes | yes |
| `ping` | yes (stat) | yes (stat) |
| `list` | yes | yes |

## CI/CD

GitHub Actions builds and pushes the multi-arch image (`linux/amd64`, `linux/arm64`) to Docker Hub.

* `ci-docker.yml`: build and push to Docker Hub. Triggered by a published GitHub release (or a
  manual dispatch against a tag). Requires `vars.DOCKERHUB_USERNAME` and `secrets.DOCKERHUB_TOKEN`.

## Dependencies

- [shadowsocks-rust](https://github.com/shadowsocks/shadowsocks-rust) (pinned by version + sha256 in the [Dockerfile](Dockerfile))
