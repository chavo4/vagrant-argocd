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

# Function to wait for service
wait_for_service() {
    local namespace=$1
    local service_name=$2
    local timeout=180  # 3 minutes timeout
    local interval=10   # 10 seconds interval
    local elapsed=0

    print_message "Waiting for service ${service_name} in namespace ${namespace}..."
    
    while [ $elapsed -lt $timeout ]; do
        if kubectl get svc -n ${namespace} ${service_name} &>/dev/null; then
            if kubectl get svc -n ${namespace} ${service_name} -o jsonpath='{.spec.ports[0].nodePort}' &>/dev/null; then
                print_message "Service ${service_name} is ready"
                return 0
            fi
        fi
        sleep $interval
        elapsed=$((elapsed + interval))
        print_warning "Still waiting for service... ($elapsed seconds elapsed)"
    done
    
    return 1
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
    path: overlays/${path}    # Changed from overlays to k8s
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
    
    if ! wait_for_service "$namespace" "$service_name"; then
        print_error "Timeout waiting for service ${service_name}"
        return 1
    fi
    
    local nodeport
    nodeport=$(kubectl get svc -n ${namespace} ${service_name} -o jsonpath='{.spec.ports[0].nodePort}')
    
    if [ -z "$nodeport" ]; then
        print_error "Failed to get NodePort for ${service_name}"
        return 1
    fi
    
    echo "$nodeport"
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

    # Get server IP
    SERVER_IP=$(get_server_ip)
    if [ -z "$SERVER_IP" ]; then
        print_error "Failed to get server IP"
        exit 1
    fi

    # Wait for services to be ready and get NodePorts
    DEV_PORT=$(get_nodeport "tetris-dev" "tetris-service")  # Changed service name
    if [ $? -ne 0 ]; then
        print_error "Failed to get dev service NodePort"
        exit 1
    fi

    PROD_PORT=$(get_nodeport "tetris-prod" "tetris-service")  # Changed service name
    if [ $? -ne 0 ]; then
        print_error "Failed to get prod service NodePort"
        exit 1
    fi

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
