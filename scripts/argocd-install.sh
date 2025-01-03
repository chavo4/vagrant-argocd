#!/bin/bash

# Get the second IP address automatically
IP_ADDRESS=$(hostname -I | awk '{print $2}')
PORT="8080"
ARGOCD_NAMESPACE="argocd"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print messages
print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Validate IP address
validate_ip() {
    if [ -z "$IP_ADDRESS" ]; then
        print_error "Could not determine IP address"
        exit 1
    fi
    print_message "Using IP address: $IP_ADDRESS"
}

# Check if kubectl is installed
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
}

# Check if cluster is accessible
check_cluster() {
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Kubernetes cluster is not accessible"
        exit 1
    fi
}

# Install ArgoCD
install_argocd() {
    print_message "Creating argocd namespace..."
    kubectl create namespace $ARGOCD_NAMESPACE

    print_message "Installing ArgoCD..."
    kubectl apply -n $ARGOCD_NAMESPACE -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

    print_message "Waiting for ArgoCD pods to be ready..."
    kubectl wait --for=condition=Ready pods --all -n $ARGOCD_NAMESPACE --timeout=300s
}

# Get ArgoCD initial admin password
get_admin_password() {
    print_message "Getting initial admin password..."
    local password=$(kubectl -n $ARGOCD_NAMESPACE get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    echo -e "${GREEN}ArgoCD Initial Admin Password:${NC} $password"
    # Save password to file
    echo "$password" > /vagrant/argocd-password.txt
    print_message "Password saved to /vagrant/argocd-password.txt"
}

# Start port forwarding
start_port_forward() {
    print_message "Starting port forwarding..."
    
    # Kill any existing port-forward processes
    pkill -f "kubectl port-forward.*$PORT:443"
    
    # Start port forwarding in background
    nohup kubectl port-forward --address $IP_ADDRESS svc/argocd-server -n $ARGOCD_NAMESPACE $PORT:443 > port-forward.log 2>&1 &
    
    # Save the PID
    echo $! > port-forward.pid
    
    print_message "Port forwarding started on https://$IP_ADDRESS:$PORT"
}

# Create start script with dynamic IP
create_start_script() {
    cat << EOF > start-argo.sh
#!/bin/bash
IP_ADDRESS=\$(hostname -I | awk '{print \$2}')
PORT="$PORT"
ARGOCD_NAMESPACE="$ARGOCD_NAMESPACE"

# Kill any existing port-forward processes
pkill -f "kubectl port-forward.*\$PORT:443"

# Start port forwarding
nohup kubectl port-forward --address \$IP_ADDRESS svc/argocd-server -n \$ARGOCD_NAMESPACE \$PORT:443 > port-forward.log 2>&1 &

echo \$! > port-forward.pid
echo "ArgoCD started on https://\$IP_ADDRESS:\$PORT"
echo "PID: \$(cat port-forward.pid)"
EOF

    chmod +x start-argo.sh
    print_message "Created start-argo.sh script"
}

# Create stop script
create_stop_script() {
    cat << 'EOF' > stop-argo.sh
#!/bin/bash
if [ -f port-forward.pid ]; then
    pid=$(cat port-forward.pid)
    kill $pid
    rm port-forward.pid
    echo "ArgoCD port forwarding stopped"
else
    echo "No port forwarding PID file found"
fi
EOF

    chmod +x stop-argo.sh
    print_message "Created stop-argo.sh script"
}

# Install ArgoCD CLI
install_argocd_cli() {
    print_message "Installing ArgoCD CLI..."
    curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
    rm argocd-linux-amd64
    print_message "ArgoCD CLI installed successfully"
}

# Main installation process
main() {
    print_message "Starting ArgoCD installation..."
    
    # Validate IP address
    validate_ip
    
    # Check prerequisites
    check_kubectl
    check_cluster
    
    # Install ArgoCD
    install_argocd
    
    # Install ArgoCD CLI
    install_argocd_cli
    
    # Get access information
    get_admin_password
    
    # Create management scripts
    create_start_script
    create_stop_script
    
    # Start port forwarding
    start_port_forward
    
    print_message "Installation complete!"
    print_warning "Note: It might take a few minutes for all services to be fully ready"
    echo -e "${GREEN}ArgoCD URL:${NC} https://$IP_ADDRESS:$PORT"
    echo -e "${GREEN}Username:${NC} admin"
    echo -e "${GREEN}Password:${NC} $(cat argocd-password.txt)"
    print_message "Use ./start-argo.sh to start and ./stop-argo.sh to stop ArgoCD"
}

# Run the installation
main