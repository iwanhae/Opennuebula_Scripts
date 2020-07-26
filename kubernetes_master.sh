if [ ! -d "/flag/hostname" ] 
then
  mkdir -p /flag/hostname
  apt update && apt install -y jq
  VMNAME=$(onegate vm show --json | jq -r '.VM | .NAME')
  echo $VMNAME > /etc/hostname
  echo "127.0.0.1 $VMNAME" >> /etc/hosts
  reboot
fi

if [ ! -d "/flag/kubernetes_master" ] 
then
  mkdir -p /flag/kubernetes_master
  sudo apt-get update && sudo apt-get install -y apt-transport-https curl
  curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
  cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
  deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
  sudo apt-get update
  sudo apt-get install -y kubelet kubeadm kubectl docker.io
  sudo apt-mark hold kubelet kubeadm kubectl docker.io
  systemctl enable docker

  kubeadm init --pod-network-cidr=10.10.0.0/16
  mkdir -p $HOME/.kube
  cp /etc/kubernetes/admin.conf $HOME/.kube/config
  kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

  HASH=sha256:$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')
  echo $HASH
  onegate vm update --data HASH=$HASH

  TOKEN=$(kubeadm token generate)

echo "$(cat <<-EOF
  onegate vm update --data TOKEN=$(kubeadm token generate)
EOF
)" >> /root/updateToken.sh
  chmod +x /root/updateToken.sh
  /root/updateToken.sh
  (crontab -l 2>/dev/null; echo "0 0,12 * * * /root/updateToken.sh") | crontab -
fi
# kubeadm join 192.168.2.204:6443 --token cssqe8.ol3jy5ytia5u5vzm --discovery-token-ca-cert-hash sha256:6a8db1fe1f207e0263f06f88d3a7401bc1713e90b9293ddafed496f4504101bd