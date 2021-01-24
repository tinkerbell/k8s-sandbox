#!/usr/bin/env bash

# stops the execution if a command or pipeline has an error
set -eu

if command -v tput >/dev/null && tput setaf 1 >/dev/null 2>&1; then
	# color codes
	RED="$(tput setaf 1)"
	RESET="$(tput sgr0)"
fi

ERR="${RED:-}ERROR:${RESET:-}"

source ./current_versions.sh

err() (
	if [ -z "${1:-}" ]; then
		cat >&2
	else
		echo "$ERR " "$@" >&2
	fi
)

candidate_interfaces() (
	ip -o link show |
		awk -F': ' '{print $2}' |
		sed 's/[ \t].*//;/^\(lo\|bond0\|\|\)$/d' |
		sort
)

validate_tinkerbell_network_interface() (
	local tink_interface=$1

	if ! candidate_interfaces | grep -q "^$tink_interface$"; then
		err "Invalid interface ($tink_interface) selected, must be one of:"
		candidate_interfaces | err
		return 1
	else
		return 0
	fi
)

generate_password() (
	head -c 12 /dev/urandom | sha256sum | cut -d' ' -f1
)

generate_envrc() (
	local tink_interface=$1

	validate_tinkerbell_network_interface "$tink_interface"

	TINKERBELL_HOST_IP=${TINKERBELL_HOST_IP:-192.168.1.1}
	TINKERBELL_NGINX_IP=${TINKERBELL_NGINX_IP:-$TINKERBELL_HOST_IP}
	TINKERBELL_NGINX_URL=${TINKERBELL_NGINX_URL:-http://$TINKERBELL_NGINX_IP:8080}
	TINKERBELL_REGISTRY_IP=${TINKERBELL_REGISTRY_IP:-$TINKERBELL_HOST_IP}
	TINKERBELL_TINK_IP=${TINKERBELL_TINK_IP:-$TINKERBELL_HOST_IP}

	local tink_password
	tink_password=$(generate_password)
	local registry_password
	registry_password=$(generate_password)
	cat <<EOF
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: boots
data:
  DATA_MODEL_VERSION: "1"
  DNS_SERVERS: 8.8.8.8
  DOCKER_REGISTRY: ${TINKERBELL_REGISTRY_IP}
  MIRROR_BASE_URL: ${TINKERBELL_NGINX_URL}
  PUBLIC_IP: ${TINKERBELL_HOST_IP}
  TINKERBELL_CERT_URL: http://${TINKERBELL_TINK_IP}:42114/cert
  TINKERBELL_GRPC_AUTHORITY: ${TINKERBELL_TINK_IP}:42113

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: dhcrelay
data:
  IF_DOWNSTREAM: $tink_interface
  IF_UPSTREAM: cni0

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: tink-client
data:
  DATA_MODEL_VERSION: "1"
  TINKERBELL_CERT_URL: http://tink-server.default.svc.cluster.local:42114/cert
  TINKERBELL_GRPC_AUTHORITY: tink-server.default.svc.cluster.local:42113

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: tink-init
data:
  OSIE_DOWNLOAD_LINK: ${OSIE_DOWNLOAD_LINK}
  TINKERBELL_TINK_WORKER_IMAGE: ${TINKERBELL_TINK_WORKER_IMAGE}

---
apiVersion: v1
kind: Secret
metadata:
  name: db
stringData:
  PGDATABASE: tinkerbell
  PGHOST: db.default.svc.cluster.local
  PGPASSWORD: tinkerbell
  PGPORT: "5432"
  PGSSLMODE: disable
  PGUSER: tinkerbell
type: Opaque

---
apiVersion: v1
kind: Secret
metadata:
  name: packet
stringData:
  API_AUTH_TOKEN: ${PACKET_API_AUTH_TOKEN:-ignored}
  API_BASE_URL: ignored
  API_CONSUMER_TOKEN: ${PACKET_CONSUMER_TOKEN:-ignored}
  PACKET_ENV: ${PACKET_ENV:-testing}
  PACKET_VERSION: ${PACKET_VERSION:-ignored}
  ROLLBAR_DISABLE: "1"
  ROLLBAR_TOKEN: ignored
type: Opaque

---
apiVersion: v1
kind: Secret
metadata:
  name: registry
stringData:
  REGISTRY_HOST: registry.default.svc.cluster.local
  REGISTRY_USERNAME: admin
  REGISTRY_PASSWORD: $registry_password
type: Opaque

---
apiVersion: v1
kind: Secret
metadata:
  name: tink-auth
stringData:
  TINK_AUTH_USERNAME: admin
  TINK_AUTH_PASSWORD: $tink_password
type: Opaque
EOF
)

main() (
	if [ -z "${1:-}" ]; then
		err "Usage: $0 network-interface-name > envrc.yaml"
		exit 1
	fi

	generate_envrc "$1"
)

main "$@"
