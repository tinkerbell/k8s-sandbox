# Deploying Tinkerbell Locally on Kubernetes with kind

This directory is an effort to merge the [k8s-sandbox](https://github.com/tinkerbell/k8s-sandbox) and [tink-kindDev](https://github.com/detiber/tink/tree/kindDev) repositories to provide a unique set of Kubernetes manifests to deploy Tinkerbell either in Vagrant, Equinix Metal, Kind+KubeVirt or else.

This is still very experimental and depends on shell scripts that will most likely screw up your system if ran outside a sandbox. You've been warned.

The following commands are given as a guideline, not as a how-to.

## Requirements

### Fix networking on Docker

Docker sets iptable's FORWARD policy to DROP. Set it to ACCEPT if running on Docker.

```
iptables -P FORWARD ACCEPT
```

### Fix networking on Kind

```
docker exec -it kind-control-plane sh -c "echo 0 >/proc/sys/net/bridge/bridge-nf-call-iptables"
```

### Fix CNI paths for k3s

If using k3s, CNI binaries and configuration files aren't in standard location and Multus won't find them.

```
mkdir -p /etc/cni /opt/cni/bin

echo "/var/lib/rancher/k3s/agent/etc/cni /etc/cni none defaults,bind 0 2" >> /etc/fstab
echo "/var/lib/rancher/k3s/data/3a24132c2ddedfad7f599daf636840e8a14efd70d4992a1b3900d2617ed89893/bin /opt/cni/bin none defaults,bind 0 2" >> /etc/fstab

mount /etc/cni
mount /opt/cni/bin/
```

### Install missing CNI plugins

Make sure that `bridge` and `static` plugins are installed, otherwise:

```
wget https://github.com/containernetworking/plugins/releases/download/v0.8.7/cni-plugins-linux-amd64-v0.8.7.tgz -O - | tar -xzC /opt/cni/bin/ ./bridge ./portmap ./static
```

### Install Multus

```
kubectl apply -f https://raw.githubusercontent.com/intel/multus-cni/master/images/multus-daemonset.yml
kubectl apply -f multus-networks.yaml
```

### Install KubeVirt

```
kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/v0.34.2/kubevirt-operator.yaml

# Skip if emulation is not required
kubectl create configmap kubevirt-config -n kubevirt --from-literal debug.useEmulation=true

kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/v0.34.2/kubevirt-cr.yaml
```

### Install Krew

```
TMPDIR="$(mktemp -d)"
cd "$TMPDIR"
curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/krew.tar.gz"
tar zxvf krew.tar.gz
KREW=./krew-"$(uname | tr '[:upper:]' '[:lower:]')_$(uname -m | sed -e 's/x86_64/amd64/' -e 's/arm.*$/arm/')"
"$KREW" install krew
rm -rf "$TMPDIR"
```

### Install virtctl

```
kubectl krew install virt
```

### Install VNC Viewer

```
apt-get install -y xvnc4viewer
```

## Install Tinkerbell

### Bootstrap

```
(
  cd ../..

  export TINKERBELL_HOST_IP=192.168.1.1
  export TINKERBELL_NGINX_IP=192.168.1.2
  export TINKERBELL_NGINX_URL=http://192.168.1.2
  export TINKERBELL_REGISTRY_IP=192.168.1.3
  export TINKERBELL_TINK_IP=192.168.1.4

  ./generate-envrc.sh eth1 > .env
  ./setup.sh
)
```

### Install

```
kubectl apply -f ../kubernetes/
```

## Setup a workflow

Coming soon...

## Start the worker

```
kubectl apply -f worker.yaml
```
