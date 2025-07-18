# Generate self-signed SSL certificate for GLPI Docker
# This script creates a self-signed certificate valid for 365 days

$certPath = ".\nginx\ssl"
$certName = "glpi.localhost"
$certValidDays = 365

Write-Host "Generating self-signed certificate for $certName..." -ForegroundColor Green

# Create certificate directory if it doesn't exist
if (!(Test-Path $certPath)) {
    New-Item -ItemType Directory -Path $certPath -Force | Out-Null
}

# Generate private key and certificate using OpenSSL
# Note: OpenSSL must be installed on your system
try {
    # Check if OpenSSL is available
    $opensslPath = Get-Command openssl -ErrorAction SilentlyContinue
    
    if ($opensslPath) {
        # Generate private key
        Write-Host "Generating private key..." -ForegroundColor Yellow
        & openssl genrsa -out "$certPath\key.pem" 2048
        
        # Generate certificate
        Write-Host "Generating certificate..." -ForegroundColor Yellow
        $subject = "/C=FR/ST=State/L=City/O=Organization/OU=IT/CN=$certName"
        & openssl req -new -x509 -key "$certPath\key.pem" -out "$certPath\cert.pem" -days $certValidDays -subj $subject
        
        Write-Host "Self-signed certificate generated successfully!" -ForegroundColor Green
        Write-Host "Certificate location: $certPath\cert.pem" -ForegroundColor Cyan
        Write-Host "Private key location: $certPath\key.pem" -ForegroundColor Cyan
    }
    else {
        Write-Host "OpenSSL is not installed. Falling back to PowerShell method..." -ForegroundColor Yellow
        
        # Alternative: Use PowerShell to create certificate (Windows only)
        $cert = New-SelfSignedCertificate `
            -DnsName $certName `
            -CertStoreLocation "Cert:\CurrentUser\My" `
            -NotAfter (Get-Date).AddDays($certValidDays) `
            -KeyExportPolicy Exportable `
            -KeySpec Signature `
            -KeyLength 2048 `
            -KeyAlgorithm RSA `
            -HashAlgorithm SHA256
        
        # Export certificate
        $certPassword = ConvertTo-SecureString -String "temporary" -Force -AsPlainText
        Export-PfxCertificate -Cert $cert -FilePath "$certPath\cert.pfx" -Password $certPassword | Out-Null
        
        Write-Host "`nCertificate created as PFX. You'll need to convert it to PEM format." -ForegroundColor Yellow
        Write-Host "Install OpenSSL and run:" -ForegroundColor Yellow
        Write-Host "openssl pkcs12 -in $certPath\cert.pfx -out $certPath\cert.pem -nodes -clcerts" -ForegroundColor Cyan
        Write-Host "openssl pkcs12 -in $certPath\cert.pfx -out $certPath\key.pem -nodes -nocerts" -ForegroundColor Cyan
    }
}
catch {
    Write-Host "Error generating certificate: $_" -ForegroundColor Red
    Write-Host "`nPlease ensure OpenSSL is installed:" -ForegroundColor Yellow
    Write-Host "- Windows: Download from https://slproweb.com/products/Win32OpenSSL.html" -ForegroundColor Cyan
    Write-Host "- Or use: winget install OpenSSL.OpenSSL" -ForegroundColor Cyan
} 