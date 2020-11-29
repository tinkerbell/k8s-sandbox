#!/bin/bash

# abort this script on errors
set -euxo pipefail

whoami

export TINKERBELL_NETWORK_INTERFACE="eth1"
export TINKERBELL_HOST_IP="192.168.1.1"
export TINKERBELL_CIDR="29"

cd /vagrant

setup_networking_netplan() (
	cat >"/etc/netplan/${TINKERBELL_NETWORK_INTERFACE}.yaml" <<EOF
network:
  renderer: networkd
  ethernets:
    ${TINKERBELL_NETWORK_INTERFACE}:
      addresses:
        - ${TINKERBELL_HOST_IP}/${TINKERBELL_CIDR}
EOF

	ip link set "${TINKERBELL_NETWORK_INTERFACE}" nomaster
	netplan apply
	sleep 3
)

setup_k3s() (
	# from https://rancher.com/docs/k3s/latest/en/installation/install-options/
	curl -fsSL "https://get.k3s.io" |
		INSTALL_K3S_EXEC="--disable traefik --kube-apiserver-arg service-node-port-range=0-65535 --write-kubeconfig-mode=644" \
			sudo -E sh -s -
)

command_exists() (
	command -v "$@" >/dev/null 2>&1
)

main() (
	export DEBIAN_FRONTEND=noninteractive

	apt-get update

	if ! command_exists k3s; then
		setup_k3s
	fi

	if [ ! -f ./deploy/kubernetes/envrc.yaml ]; then
		./generate-envrc.sh "${TINKERBELL_NETWORK_INTERFACE}" >./deploy/kubernetes/envrc.yaml
	fi

	setup_networking_netplan

	./setup.sh
)

main
