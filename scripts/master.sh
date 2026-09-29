#!/bin/bash

set -eux

apt-get update -y

apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gpg \
  containerd

# --------------------------------------------------
# Containerd
# --------------------------------------------------

mkdir -p /etc/containerd

containerd config default > /etc/containerd/config.toml

sed -i \
's/SystemdCgroup = false/SystemdCgroup = true/' \
/etc/containerd/config.toml

systemctl restart containerd

systemctl enable containerd

# --------------------------------------------------
# Kubernetes repository
# --------------------------------------------------

mkdir -p /etc/apt/keyrings

curl -fsSL \
https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key \
| gpg --dearmor \
-o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' \
> /etc/apt/sources.list.d/kubernetes.list

apt-get update

apt-get install -y \
kubelet \
kubeadm \
kubectl

apt-mark hold kubelet kubeadm kubectl

systemctl enable kubelet

# --------------------------------------------------
# Disable swap
# --------------------------------------------------

swapoff -a

sed -i '/ swap / s/^/#/' /etc/fstab

echo "MASTER SETUP COMPLETED"
