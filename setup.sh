#!/usr/bin/env bash
# shellcheck disable=SC2034

# stops the execution if a command or pipeline has an error
set -eu

# Tinkerbell stack Linux setup script
#
# See https://tinkerbell.org/setup for the installation steps.

# file to hold all environment variables
ENV_FILE=$(pwd)/deploy/kubernetes/envrc.yaml

DEPLOYDIR=$(pwd)/deploy
readonly DEPLOYDIR

if command -v tput >/dev/null && tput setaf 1 >/dev/null 2>&1; then
	# color codes
	RED="$(tput setaf 1)"
	GREEN="$(tput setaf 2)"
	YELLOW="$(tput setaf 3)"
	RESET="$(tput sgr0)"
fi

INFO="${GREEN:-}INFO:${RESET:-}"
ERR="${RED:-}ERROR:${RESET:-}"
WARN="${YELLOW:-}WARNING:${RESET:-}"
BLANK="      "
NEXT="${GREEN:-}NEXT:${RESET:-}"

generate_certificates() (
	kubectl apply -f "$DEPLOYDIR/kubernetes/cert-manager.yaml"
	kubectl wait deploy -n cert-manager cert-manager --for condition=available --timeout 120s
	kubectl wait deploy -n cert-manager cert-manager-webhook --for condition=available --timeout 120s
	kubectl wait deploy -n cert-manager cert-manager-cainjector --for condition=available --timeout 120s

	kubectl apply -f "$DEPLOYDIR/kubernetes/cert-manager.crds.yaml"

	kubectl apply -f "$DEPLOYDIR/kubernetes/certs.yaml"
	kubectl wait cert server --for condition=ready --timeout 120s
)

install_secrets() (
	kubectl apply -f "$DEPLOYDIR/kubernetes/envrc.yaml"
)

command_exists() (
	command -v "$@" >/dev/null 2>&1
)

check_command() (
	if command_exists "$1"; then
		echo "$BLANK Found prerequisite: $1"
		return 0
	else
		echo "$ERR Prerequisite command not installed: $1"
		return 1
	fi
)

check_prerequisites() (
	echo "$INFO verifying prerequisites for"
	failed=0
	check_command kubectl || failed=1

	if [ $failed -eq 1 ]; then
		echo "$ERR Prerequisites not met. Please install the missing commands and re-run $0."
		exit 1
	fi
)

whats_next() (
	echo "$NEXT  1. Run 'kubectl apply -f $DEPLOYDIR/kubernetes'."
	echo "$BLANK 2. Try executing your fist workflow."
	echo "$BLANK    Follow the steps described in https://tinkerbell.org/examples/hello-world/ to say 'Hello World!' with a workflow."
)

do_setup() (
	echo "$INFO starting tinkerbell stack setup"
	check_prerequisites

	if [ ! -f "$ENV_FILE" ]; then
		echo "$ERR Run './generate-envrc.sh network-interface > \"$ENV_FILE\"' before continuing."
		exit 1
	fi

	generate_certificates
	install_secrets

	echo "$INFO tinkerbell stack setup completed successfully"
	whats_next
)

# wrapped up in a function so that we have some protection against only getting
# half the file during "curl | sh"
do_setup
