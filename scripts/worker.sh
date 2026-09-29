#!/bin/bash

set -eux

apt-get update -y

apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gpg \
  containerd \
  wget

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
# Kubernetes
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

# --------------------------------------------------
# CloudWatch Agent
# --------------------------------------------------

cd /tmp

wget https://amazoncloudwatch-agent.s3.amazonaws.com/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb

dpkg -i amazon-cloudwatch-agent.deb

# --------------------------------------------------
# CloudWatch configuration
# --------------------------------------------------

cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'EOF'
{
  "agent": {
    "metrics_collection_interval": 60
  },

  "metrics": {
    "namespace": "CWAgent",

    "append_dimensions": {
      "AutoScalingGroupName": "${aws:AutoScalingGroupName}",
      "InstanceId": "${aws:InstanceId}"
    },

    "metrics_collected": {

      "mem": {
        "measurement": [
          "mem_used_percent"
        ],

        "metrics_collection_interval": 60
      },

      "disk": {
        "measurement": [
          "used_percent"
        ],

        "resources": [
          "*"
        ],

        "metrics_collection_interval": 60
      }
    }
  }
}
EOF

# --------------------------------------------------
# Start CloudWatch Agent
# --------------------------------------------------

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
-a fetch-config \
-m ec2 \
-c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
-s

systemctl enable amazon-cloudwatch-agent

echo "WORKER SETUP COMPLETED"
