# Deploying Tinkerbell Locally on Kubernetes with kind

This directory is an effort to merge the [k8s-sandbox](https://github.com/tinkerbell/k8s-sandbox) and [tink-kindDev](https://github.com/detiber/tink/tree/kindDev) repositories to provide a unique set of Kubernetes manifests to deploy Tinkerbell either in Vagrant, Equinix Metal, kind+KubeVirt or else.

The following commands are given as a guideline, not as a how-to.

## Requirements

### [kind] Install kind

Follow official [documentation](https://kind.sigs.k8s.io/docs/user/quick-start/#installation).

```
sudo curl -Lo /usr/local/bin/kind https://kind.sigs.k8s.io/dl/v0.9.0/kind-linux-amd64
sudo chmod +x /usr/local/bin/kind
```

### [kind] Create kind cluster

```
kind create cluster --config kind-config.yaml
```

### Fix networking on Docker

Docker sets iptable's FORWARD policy to DROP. Set it to ACCEPT if running on Docker.

```
iptables -P FORWARD ACCEPT
```

### [kind] Fix networking

```
docker exec -it kind-control-plane sh -c "echo 0 >/proc/sys/net/bridge/bridge-nf-call-iptables"
```

### [k3s] Fix CNI paths

If using k3s, CNI binaries and configuration files aren't in standard location and Multus won't find them.

```
mkdir -p /etc/cni /opt/cni/bin

echo "/var/lib/rancher/k3s/agent/etc/cni /etc/cni none defaults,bind 0 2" >> /etc/fstab
echo "/var/lib/rancher/k3s/data/3a24132c2ddedfad7f599daf636840e8a14efd70d4992a1b3900d2617ed89893/bin /opt/cni/bin none defaults,bind 0 2" >> /etc/fstab

mount /etc/cni
mount /opt/cni/bin/
```

### Install missing CNI plugins

Make sure that `bridge`, `portmap` and `static` plugins are installed, otherwise:

If using kind:

```
docker exec -it kind-control-plane sh -c "curl -L https://github.com/containernetworking/plugins/releases/download/v0.8.7/cni-plugins-linux-amd64-v0.8.7.tgz | tar -xzC /opt/cni/bin/ ./bridge ./portmap ./static"
```

Otherwise:

```
curl -L https://github.com/containernetworking/plugins/releases/download/v0.8.7/cni-plugins-linux-amd64-v0.8.7.tgz | tar -xzC /opt/cni/bin/ ./bridge ./portmap ./static
```

### Install Multus

```
curl https://raw.githubusercontent.com/intel/multus-cni/master/images/multus-daemonset.yml | sed 's|:stable|:latest|' | kubectl apply -f-
kubectl apply -f multus-networks.yaml
```

### Install KubeVirt

```
kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/v0.34.2/kubevirt-operator.yaml
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

  export TINKERBELL_NETWORK_INTERFACE="docker0"
  export TINKERBELL_HOST_IP=192.168.1.1
  export TINKERBELL_NGINX_IP=192.168.1.2
  export TINKERBELL_NGINX_URL=http://192.168.1.2
  export TINKERBELL_REGISTRY_IP=192.168.1.3
  export TINKERBELL_TINK_IP=192.168.1.4

  ./generate-envrc.sh "${TINKERBELL_NETWORK_INTERFACE}" >./deploy/kubernetes/envrc.yaml
  ./setup.sh
)
```

### Install

```
kubectl apply -f ../kubernetes/
```

## Setup a workflow

```
cat >hardware-data.json <<EOF
{
  "id": "ce2e62ed-826f-4485-a39f-a82bb74338e2",
  "metadata": {
    "facility": {
      "facility_code": "onprem"
    },
    "instance": {},
    "state": ""
  },
  "network": {
    "interfaces": [
      {
        "dhcp": {
          "arch": "x86_64",
          "ip": {
            "address": "192.168.1.5",
            "gateway": "192.168.1.1",
            "netmask": "255.255.255.248"
          },
          "mac": "08:00:27:00:00:01",
          "uefi": false
        },
        "netboot": {
          "allow_pxe": true,
          "allow_workflow": true
        }
      }
    ]
  }
}
EOF
```

```
cat >hello-world.yml  <<EOF
version: "0.1"
name: hello_world_workflow
global_timeout: 600
tasks:
  - name: "hello world"
    worker: "{{.device_1}}"
    actions:
      - name: "hello_world"
        image: hello-world
        timeout: 60
EOF
```

```
kubectl run skopeo -i --rm --restart=Never --image=none --overrides='{"spec":{"containers":[{"args":["copy","--dest-creds=$(REGISTRY_USERNAME):$(REGISTRY_PASSWORD)","--dest-tls-verify=false","docker://docker.io/hello-world:latest","docker://$(REGISTRY_HOST)/hello-world:latest"],"envFrom":[{"secretRef":{"name":"registry"}}],"image":"quay.io/containers/skopeo:v1.1.1","name":"skopeo"}]}}'
```

```
kubectl exec -i $(kubectl get pod -l app=tink-cli -o name) -- tink hardware push < hardware-data.json
TEMPLATE_ID=`kubectl exec -i $(kubectl get pod -l app=tink-cli -o name) -- tink template create --name hello-world < hello-world.yml | awk -F: '{print $2}'`
kubectl exec -i $(kubectl get pod -l app=tink-cli -o name) -- tink workflow create -t ${TEMPLATE_ID} -r '{"device_1":"08:00:27:00:00:01"}'
```

## Start the worker

```
kubectl apply -f worker.yaml
```
