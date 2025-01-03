#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default Kubernetes version if not set
KUBE_VERSION=${KUBE_VERSION}

# Log file
LOG_FILE="/var/log/k8s_install.log"

# Function to log messages
log() {
    local level=$1
    shift
    local message=$@
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a ${LOG_FILE}
}

# Function to check command status
check_status() {
    if [ $? -eq 0 ]; then
        log "INFO" "${GREEN}✓${NC} $1 completed successfully"
    else
        log "ERROR" "${RED}✗${NC} $1 failed"
        exit 1
    fi
}

# Function to copy kubeconfig
copyConfig() {
    log "INFO" "Copying kubeconfig..."
    mkdir -p $HOME/.kube
    sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
    check_status "Kubeconfig copy"
}

# Function to install HELM
installHELM() {
    log "INFO" "Installing Helm..."
    if ! command -v helm &> /dev/null; then
        curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
        sudo chmod 700 get_helm.sh
        ./get_helm.sh
        export PATH="$PATH:/usr/local/bin"
        check_status "Helm installation"
        rm -f get_helm.sh
    else
        log "INFO" "Helm is already installed"
    fi
}

# Function to check system requirements
check_requirements() {
    log "INFO" "Checking system requirements..."
    
    # Check CPU
    CPU_CORES=$(nproc)
    if [ ${CPU_CORES} -lt 2 ]; then
        log "ERROR" "Minimum 2 CPU cores required. Found: ${CPU_CORES}"
        exit 1
    fi

    # Check RAM
    TOTAL_RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
    if [ ${TOTAL_RAM_GB} -lt 2 ]; then
        log "ERROR" "Minimum 2GB RAM required. Found: ${TOTAL_RAM_GB}GB"
        exit 1
    fi

    # Check disk space
    ROOT_DISK_GB=$(df -BG / | awk 'NR==2 {print $4}' | tr -d 'G')
    if [ ${ROOT_DISK_GB} -lt 20 ]; then
        log "ERROR" "Minimum 20GB disk space required. Found: ${ROOT_DISK_GB}GB"
        exit 1
    fi
}

# Main installation process
main() {
    # Start installation
    log "INFO" "Starting Kubernetes ${KUBE_VERSION} installation"
    
    # Check requirements
    check_requirements

    # Get OS information
    currentOS=$(grep "^PRETTY_NAME=" /etc/os-release | awk -F'=' '{print $2}')
    log "INFO" "Installing on ${YELLOW}${currentOS}${NC}"

    # Disable firewalld
    if systemctl is-active --quiet firewalld; then
        log "INFO" "Disabling firewalld..."
        sudo systemctl stop firewalld
        sudo systemctl disable firewalld
        check_status "Firewalld disable"
    fi

    # Disable swap
    log "INFO" "Disabling swap..."
    sudo swapoff -a
    sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
    check_status "Swap disable"

    # Setup kernel modules
    log "INFO" "Setting up kernel modules..."
    cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
    sudo modprobe overlay
    sudo modprobe br_netfilter
    check_status "Kernel modules setup"

    # Configure sysctl
    log "INFO" "Configuring sysctl..."
    sudo tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
    sudo sysctl --system
    check_status "Sysctl configuration"

    # Install required packages
    log "INFO" "Installing required packages..."
    sudo yum install -y curl gnupg2 yum-utils device-mapper-persistent-data lvm2
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo yum install -y docker-ce docker-ce-cli containerd.io vim
    check_status "Package installation"

    # Configure containerd
    log "INFO" "Configuring containerd..."
    sudo containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1
    sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
    sudo systemctl restart containerd
    sudo systemctl enable containerd
    check_status "Containerd configuration"

    # Install Kubernetes components
    log "INFO" "Installing Kubernetes components..."
    cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v${KUBE_VERSION}/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v${KUBE_VERSION}/rpm/repodata/repomd.xml.key
EOF
    sudo yum install -y kubelet kubeadm kubectl
    sudo systemctl enable kubelet
    sudo systemctl start kubelet
    check_status "Kubernetes installation"

    # Configure SELinux
    log "INFO" "Configuring SELinux..."
    SELINUX=$(grep "^SELINUX=" /etc/selinux/config | awk -F'=' '{print $2}')
    if [ "$SELINUX" != "permissive" ]; then
        sudo sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
        sudo setenforce Permissive
        log "WARNING" "System reboot recommended for SELinux changes"
    fi

    # Initialize cluster
    log "INFO" "Initializing Kubernetes cluster..."
    myhost=$(hostname -I | awk '{print $2}')
    sudo kubeadm init --apiserver-advertise-address=$myhost \
                      --control-plane-endpoint=$myhost \
                      --apiserver-cert-extra-sans=$myhost \
                      --pod-network-cidr=172.16.0.0/16 -v5
    check_status "Cluster initialization"

    # Configure kubectl
    copyConfig

    # Remove control-plane taint
    log "INFO" "Removing control-plane taint..."
    kubectl taint nodes --all node-role.kubernetes.io/control-plane-
    check_status "Taint removal"

    # Create join token
    log "INFO" "Creating join token..."
    kubeadm token create --print-join-command > /vagrant/token-join
    check_status "Token creation"

    # Install CNI (Calico)
    log "INFO" "Installing Calico CNI..."
    curl -L https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml -o calico.yaml
    kubectl apply -f calico.yaml
    check_status "Calico installation"

    # Install Helm
    installHELM

    # Install local-path-provisioner
    log "INFO" "Installing local-path-provisioner..."
    kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.23/deploy/local-path-storage.yaml
    check_status "Local-path-provisioner installation"

    # Install NGINX Ingress Controller
    log "INFO" "Installing NGINX Ingress Controller..."
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update
    helm install nginx-ingress ingress-nginx/ingress-nginx \
        --create-namespace \
        --namespace nginx \
        --set controller.image.tag=v1.8.1 \
        --set controller.service.externalIPs={"$myhost"} \
        --set controller.admissionWebhooks.enabled=false \
        --set-string controller.config.proxy-body-size="10m" \
        --set-string controller.config.client-max-body-size="10m" \
        --version 4.7.1 \
        --set controller.ingressClass=nginx
    check_status "NGINX Ingress Controller installation"

    log "INFO" "${GREEN}Installation completed successfully!${NC}"
    log "INFO" "Cluster endpoint: ${myhost}"
    log "INFO" "Config file: $HOME/.kube/config"
}

# Run main function
main 2>&1 | tee -a ${LOG_FILE}