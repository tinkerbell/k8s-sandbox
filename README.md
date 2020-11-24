![](https://img.shields.io/badge/Stability-Experimental-red.svg)

# k8s-sandbox

This repository is [Experimental](https://github.com/packethost/standards/blob/master/experimental-statement.md) meaning that it's based on untested ideas or techniques and not yet established or finalized or involves a radically new and innovative style! This means that support is best effort (at best!) and we strongly encourage you to NOT use this in production.

[Tinkerbell](https://tinkerbell.org/) is made of different components: osie, boots, tink-server, tink-worker and so on. Currently they are under heavy development and we are working around the release process for all the components.

Here is a quick way to get the Tinkerbell stack up and running on [Kubernetes](https://kubernetes.io/).

Currently it supports:

1. [Vagrant](https://www.vagrantup.com/) with libvirt and VirtualBox
2. [Terraform](https://www.terraform.io/) on [Equinix Metal](https://metal.equinix.com/)

## Getting Started

Follow documentation [Local Setup with Vagrant](https://docs.tinkerbell.org/setup/local-vagrant/) or [Packet Setup with Terraform](https://docs.tinkerbell.org/setup/packet-terraform/) and replace:

- `docker-compose up -d` → `kubectl apply -f /vagrant/deploy/kubernetes/`
- `docker-compose ps` → `kubectl get pods`
- `docker-compose logs -f tink-server boots nginx` → `kubectl logs -f -l 'app in (tink-server, boots, nginx)'`
- `docker exec -i deploy_tink-cli_1 tink ...` → `kubectl exec -i $(kubectl get pod -l app=tink-cli -o name) -- tink ...`

Deploying on a standalone Kubernetes cluster is not yet supported.

## Limitations

Tinkerbell is unlikely to run on an existing Kubernetes cluster without additional configurations that require privileged, node access to Kubernetes. Also, multi-node clusters are not supported at the moment.

### Docker and Shell Scripts

The installation process is ported from the [Sandbox](https://github.com/tinkerbell/sandbox), which uses Docker Compose, and is still heavily dependent on shell scripts running locally and Docker CLI.

### Host Path

The NGINX data directory requires to be filled with about 4GB of data (mostly [OSIE](https://github.com/tinkerbell/osie)). It is actually initialized from the `setup.sh` script before Tinkerbell is installed. The data is installed in a local directory and Kubernetes access it through a [hostPath](https://kubernetes.io/docs/concepts/storage/volumes/#hostpath).

### Host Network and Service Node Ports

Boots needs to access the same layer 2 network than the worker machine, and Hegel needs to be on the same layer 3 network. It is achieved using [hostNetwork](https://kubernetes.io/docs/concepts/policy/pod-security-policy/#host-namespaces). Moreover, these services must run on ports ranging from 67 to 50061, which requires to to setup Kubelet's [service-node-port-range](https://kubernetes.io/docs/concepts/services-networking/service/#nodeport) accordingly.
