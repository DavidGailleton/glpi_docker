# SSL Certificate Configuration for GLPI Docker

This directory contains SSL certificates for the nginx HTTPS configuration.

## Using Self-Signed Certificates

To generate self-signed certificates, run one of the following scripts from the project root:

**Windows (PowerShell):**
```powershell
.\generate-self-signed-cert.ps1
```

**Linux/macOS/WSL (Bash):**
```bash
chmod +x generate-self-signed-cert.sh  # Only needed first time
./generate-self-signed-cert.sh
```

Both scripts will create:
- `cert.pem` - The SSL certificate
- `key.pem` - The private key

## Using Your Own Certificates

To use your own SSL certificates:

1. Place your certificate files in this directory (`nginx/ssl/`)
2. Ensure the files are named:
   - `cert.pem` - Your SSL certificate (or certificate chain)
   - `key.pem` - Your private key

### Certificate Requirements:
- The certificate should be in PEM format
- The private key should be unencrypted
- File permissions will be handled by Docker

### Example: Converting from other formats

**From CRT/KEY to PEM:**
```bash
# If your certificate is already in CRT format, just rename it
cp your-certificate.crt cert.pem
cp your-private-key.key key.pem
```

**From PFX/P12 to PEM:**
```bash
# Extract certificate
openssl pkcs12 -in certificate.pfx -out cert.pem -nodes -clcerts

# Extract private key
openssl pkcs12 -in certificate.pfx -out key.pem -nodes -nocerts
```

**From DER to PEM:**
```bash
# Convert certificate
openssl x509 -inform der -in certificate.der -out cert.pem

# Convert private key
openssl rsa -inform der -in private-key.der -out key.pem
```

## Security Notes

1. **Never commit private keys to version control!** The `.gitignore` should exclude all files in this directory.
2. Set appropriate file permissions on your certificates:
   ```bash
   chmod 644 cert.pem
   chmod 600 key.pem
   ```
3. For production use, always use certificates from a trusted Certificate Authority (CA).

## Troubleshooting

If nginx fails to start with SSL errors:

1. Check certificate validity:
   ```bash
   openssl x509 -in cert.pem -text -noout
   ```

2. Verify private key matches certificate:
   ```bash
   openssl x509 -noout -modulus -in cert.pem | openssl md5
   openssl rsa -noout -modulus -in key.pem | openssl md5
   ```
   (These values should match)

3. Check nginx error logs:
   ```bash
   docker-compose logs nginx
   ``` 