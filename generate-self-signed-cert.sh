#!/bin/bash

# Generate self-signed SSL certificate for GLPI Docker
# This script creates a self-signed certificate valid for 365 days

CERT_PATH="./nginx/ssl"
CERT_NAME="glpi.localhost"
CERT_VALID_DAYS=365

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Generating self-signed certificate for $CERT_NAME...${NC}"

# Create certificate directory if it doesn't exist
if [ ! -d "$CERT_PATH" ]; then
    mkdir -p "$CERT_PATH"
    echo -e "${YELLOW}Created directory: $CERT_PATH${NC}"
fi

# Check if OpenSSL is available
if ! command -v openssl &> /dev/null; then
    echo -e "${RED}Error: OpenSSL is not installed!${NC}"
    echo -e "${YELLOW}Please install OpenSSL:${NC}"
    echo -e "${CYAN}  Ubuntu/Debian: sudo apt-get install openssl${NC}"
    echo -e "${CYAN}  CentOS/RHEL: sudo yum install openssl${NC}"
    echo -e "${CYAN}  macOS: brew install openssl${NC}"
    exit 1
fi

# Generate private key
echo -e "${YELLOW}Generating private key...${NC}"
openssl genrsa -out "$CERT_PATH/key.pem" 2048
if [ $? -ne 0 ]; then
    echo -e "${RED}Error generating private key!${NC}"
    exit 1
fi

# Generate certificate signing request and certificate
echo -e "${YELLOW}Generating certificate...${NC}"

# Create OpenSSL config for certificate with SANs
cat > "$CERT_PATH/openssl.cnf" << EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
C = FR
ST = State
L = City
O = Organization
OU = IT
CN = $CERT_NAME

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = $CERT_NAME
DNS.2 = localhost
DNS.3 = *.localhost
IP.1 = 127.0.0.1
IP.2 = ::1
EOF

# Generate certificate with SANs
openssl req -new -x509 \
    -key "$CERT_PATH/key.pem" \
    -out "$CERT_PATH/cert.pem" \
    -days $CERT_VALID_DAYS \
    -config "$CERT_PATH/openssl.cnf"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Self-signed certificate generated successfully!${NC}"
    echo -e "${CYAN}Certificate location: $CERT_PATH/cert.pem${NC}"
    echo -e "${CYAN}Private key location: $CERT_PATH/key.pem${NC}"
    
    # Clean up temporary config file
    rm -f "$CERT_PATH/openssl.cnf"
    
    # Set appropriate permissions
    chmod 644 "$CERT_PATH/cert.pem"
    chmod 600 "$CERT_PATH/key.pem"
    echo -e "${GREEN}Permissions set: cert.pem (644), key.pem (600)${NC}"
    
    # Display certificate information
    echo -e "\n${YELLOW}Certificate details:${NC}"
    openssl x509 -in "$CERT_PATH/cert.pem" -text -noout | grep -E "Subject:|Not Before:|Not After:|Subject Alternative Name:" -A 1
else
    echo -e "${RED}Error generating certificate!${NC}"
    # Clean up temporary config file
    rm -f "$CERT_PATH/openssl.cnf"
    exit 1
fi

echo -e "\n${GREEN}Done! You can now use these certificates with your nginx configuration.${NC}"
echo -e "${YELLOW}Note: Since this is a self-signed certificate, browsers will show a security warning.${NC}" 