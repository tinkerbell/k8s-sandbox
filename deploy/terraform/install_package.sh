#!/usr/bin/env bash

YUM="yum"
APT="apt"
YUM_CONFIG_MGR="yum-config-manager"
WHICH_YUM=$(command -v $YUM)
WHICH_APT=$(command -v $APT)
YUM_INSTALL="$YUM install"
APT_INSTALL="$APT install"
declare -a YUM_LIST=("https://download.docker.com/linux/centos/7/x86_64/stable/Packages/containerd.io-1.2.6-3.3.el7.x86_64.rpm"
	"docker-ce"
	"docker-ce-cli"
	"epel-release"
	"pass"
	"python3")
declare -a APT_LIST=("docker.io"
	"pass")

add_yum_repo() (
	$YUM_CONFIG_MGR --add-repo https://download.docker.com/linux/centos/docker-ce.repo
)

update_yum() (
	$YUM_INSTALL -y yum-utils
	add_yum_repo
)

update_apt() (
	$APT update
	DEBIAN_FRONTEND=noninteractive $APT --yes --force-yes -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade
)

restart_docker_service() (
	service docker restart
)
install_yum_packages() (
	$YUM_INSTALL "${YUM_LIST[@]}" -y
)

install_apt_packages() (
	$APT_INSTALL "${APT_LIST[@]}" -y
)

install_k3s() (
	# from https://rancher.com/docs/k3s/latest/en/installation/install-options/
	curl -fsSL "https://get.k3s.io" |
		INSTALL_K3S_EXEC="--disable traefik --docker --kube-apiserver-arg service-node-port-range=0-65535" \
			sh -s -
)

main() (
	if [[ -n $WHICH_YUM ]]; then
		update_yum
		install_yum_packages
		restart_docker_service
		install_k3s
	elif [[ -n $WHICH_APT ]]; then
		update_apt
		install_apt_packages
		restart_docker_service
		install_k3s
	else
		echo "Unknown platform. Error while installing the required packages"
		exit 1
	fi
)

main
