
### KUBERNETES WORKDER NODE install


sudo swapoff -a
 export PATH=$PATH:/usr/local/bin



CNI_PLUGINS_VERSION="v1.1.1"
ARCH="amd64"
DEST="/opt/cni/bin"
sudo mkdir -p "$DEST"
/usr/bin/curl -L "https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGINS_VERSION}/cni-plugins-linux-${ARCH}-${CNI_PLUGINS_VERSION}.tgz" | sudo tar -C "$DEST" -xz


DOWNLOAD_DIR="/usr/local/bin"
sudo mkdir -p "$DOWNLOAD_DIR"
export PATH=$PATH:$DOWNLOAD_DIR
CRICTL_VERSION="v1.25.0"
ARCH="amd64"
/usr/bin/curl -L "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-${ARCH}.tar.gz" | sudo tar -C $DOWNLOAD_DIR -xz


RELEASE="$(/usr/bin/curl -sSL https://dl.k8s.io/release/stable.txt)"
ARCH="amd64"
cd $DOWNLOAD_DIR
sudo /usr/bin/curl -L --remote-name-all https://dl.k8s.io/release/${RELEASE}/bin/linux/${ARCH}/{kubeadm,kubelet}
sudo chmod +x {kubeadm,kubelet}

RELEASE_VERSION="v0.4.0"
/usr/bin/curl -sSL "https://raw.githubusercontent.com/kubernetes/release/${RELEASE_VERSION}/cmd/kubepkg/templates/latest/deb/kubelet/lib/systemd/system/kubelet.service" | sed "s:/usr/bin:${DOWNLOAD_DIR}:g" | sudo tee /etc/systemd/system/kubelet.service
sudo mkdir -p /etc/systemd/system/kubelet.service.d
/usr/bin/curl -sSL "https://raw.githubusercontent.com/kubernetes/release/${RELEASE_VERSION}/cmd/kubepkg/templates/latest/deb/kubeadm/10-kubeadm.conf" | sed "s:/usr/bin:${DOWNLOAD_DIR}:g" | sudo tee /etc/systemd/system/kubelet.service.d/10-kubeadm.conf


sudo systemctl enable --now kubelet

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system


lsmod | grep br_netfilter
lsmod | grep overlay

sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward


echo "Download Kubectl"
kubectlVersion=`/usr/bin/curl -L -s https://dl.k8s.io/release/stable.txt`
/usr/bin/curl -LO "https://dl.k8s.io/release/${kubectlVersion}/bin/linux/amd64/kubectl"
file /usr/local/bin/kubectl 

#sudo /usr/bin/install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
sudo chmod 755 /usr/local/bin/kubectl



/usr/bin/chmod +x kubectl
/usr/bin/mkdir -p ~/.local/bin
/usr/bin/cp ./kubectl ~/.local/bin/kubectl
# and then append (or prepend) ~/.local/bin to $PATH


source /usr/share/bash-completion/bash_completion
echo 'source <(kubectl completion bash)' >>~/.bashrc

kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
sudo chmod a+r /etc/bash_completion.d/kubectl


echo  export PATH=$PATH:/usr/local/bin >>  ~/.bashrc
source ~/.bashrc


export KUBECONFIG=/etc/kubernetes/admin.conf



#
echo CONTAINERD session
cd /usr/local/
curl -LO https://github.com/containerd/containerd/releases/download/v1.7.1/containerd-1.7.1-linux-amd64.tar.gz
tar Cxzvf /usr/local containerd-1.7.1-linux-amd64.tar.gz
curl -LO https://raw.githubusercontent.com/containerd/containerd/main/containerd.service 
cp containerd.service /usr/lib/systemd/system/
systemctl daemon-reload && sleep 1
systemctl enable --now containerd
curl -LO https://github.com/opencontainers/runc/releases/download/v1.1.7/runc.amd64
install -m 755 runc.amd64 /usr/local/sbin/runc
crictl config --set runtime-endpoint=unix:///run/containerd/containerd.sock --set image-endpoint=unix:///run/containerd/containerd.sock

echo SO dependencies
which yum && yum install ebtables ethtool socat tc conntrack -y
which apt && apt install ebtables ethtool socat tc conntrack -y
echo avoid init errors
ln -s /usr/local/bin/crictl /usr/bin/
ln -s /usr/local/bin/kubelet /usr/bin/




#
echo additional settings
echo "export KUBECONFIG=/etc/kubernetes/admin.conf" >> /root/.bash_profile 
echo "
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config"  >> /etc/skel/.bash_profile 
  
  echo "
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config"  >> ~/.bash_profile 
#
