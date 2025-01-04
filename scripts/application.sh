#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# GitHub repository URL
REPO_URL="https://github.com/chavo1/vagrant-argocd.git"

# Function to print messages
print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# Function to print errors
print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to print warnings/highlights
print_warning() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

# Function to create application YAML
create_application() {
    local name=$1
    local path=$2
    
    cat << EOF > ${name}-application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: tetris-${name}
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ${REPO_URL}
    targetRevision: HEAD
    path: overlays/${path}
  destination:
    server: https://kubernetes.default.svc
    namespace: tetris-${name}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

    print_message "Created ${name}-application.yaml"
}

# Function to apply application
apply_application() {
    local name=$1
    
    if kubectl apply -f ${name}-application.yaml; then
        print_message "Applied ${name}-application.yaml successfully"
    else
        print_error "Failed to apply ${name}-application.yaml"
        exit 1
    fi
}

# Function to get NodePort
get_nodeport() {
    local namespace=$1
    local service_name=$2
    kubectl get svc -n ${namespace} ${service_name} -o jsonpath='{.spec.ports[0].nodePort}'
}

# Function to get server IP
get_server_ip() {
    hostname -I | awk '{print $2}'
}

# Main function
main() {
    print_message "Creating and applying ArgoCD applications..."

    # Create and apply dev application
    create_application "dev" "dev"
    apply_application "dev"

    # Create and apply prod application
    create_application "prod" "prod"
    apply_application "prod"

    print_message "All applications created and applied successfully!"

    # Display application status
    print_message "\nChecking application status:"
    kubectl get applications -n argocd

    # Wait for services to be created
    print_message "\nWaiting for services to be ready..."
    sleep 30

    # Get server IP
    SERVER_IP=$(get_server_ip)

    # Get NodePorts
    DEV_PORT=$(get_nodeport "tetris-dev" "dev-tetris")
    PROD_PORT=$(get_nodeport "tetris-prod" "prod-tetris")

    # Display access information
    echo -e "\n${YELLOW}=== Access Information ===${NC}"
    echo -e "${GREEN}Development Environment:${NC}"
    echo -e "URL: http://${SERVER_IP}:${DEV_PORT}"
    echo -e "\n${GREEN}Production Environment:${NC}"
    echo -e "URL: http://${SERVER_IP}:${PROD_PORT}"
    
    # Display ArgoCD access
    echo -e "\n${GREEN}ArgoCD Dashboard:${NC}"
    echo -e "URL: https://${SERVER_IP}:8080"
    echo -e "Username: admin"
    echo -e "Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"
}

# Run main function
main
