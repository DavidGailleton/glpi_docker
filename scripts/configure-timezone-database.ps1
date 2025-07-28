#!/usr/bin/env pwsh
# Script pour configurer les timezones dans MariaDB pour GLPI
# Ce script doit être exécuté après que les conteneurs Docker soient en cours d'exécution

Write-Host "Configuration des timezones MariaDB pour GLPI" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green

# Vérifier que Docker Compose est en cours d'exécution
$mariadbRunning = docker ps --filter "name=mariadb" --format "{{.Names}}" | Select-String "mariadb"
if (-not $mariadbRunning) {
    Write-Host "Erreur : Le conteneur MariaDB n'est pas en cours d'exécution." -ForegroundColor Red
    Write-Host "Veuillez d'abord lancer Docker Compose avec : docker-compose up -d" -ForegroundColor Yellow
    exit 1
}

# Demander le mot de passe root MariaDB
Write-Host "`nVeuillez entrer le mot de passe root de MariaDB :" -ForegroundColor Yellow
$rootPassword = Read-Host -AsSecureString
$rootPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($rootPassword))

Write-Host "`nÉtape 1 : Chargement des données de timezone..." -ForegroundColor Cyan

# Charger les données de timezone
# Sur Windows, nous devons télécharger les données de timezone depuis le dépôt MariaDB
$tzDataUrl = "https://downloads.mariadb.com/MariaDB/mariadb-tzdata/tzdata.tar.gz"
$tzDataFile = "tzdata.tar.gz"

Write-Host "Téléchargement des données de timezone depuis MariaDB..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri $tzDataUrl -OutFile $tzDataFile
    Write-Host "Téléchargement terminé." -ForegroundColor Green
} catch {
    Write-Host "Erreur lors du téléchargement des données de timezone : $_" -ForegroundColor Red
    exit 1
}

# Copier le fichier dans le conteneur
Write-Host "Copie des données dans le conteneur MariaDB..." -ForegroundColor Yellow
docker cp $tzDataFile mariadb:/tmp/tzdata.tar.gz

# Extraire et charger les données
Write-Host "Extraction et chargement des données de timezone..." -ForegroundColor Yellow
$loadTzData = @"
cd /tmp && \
tar -xzf tzdata.tar.gz && \
mysql -uroot -p'$rootPasswordPlain' mysql < tzdata.sql
"@

docker exec -i mariadb bash -c $loadTzData

if ($LASTEXITCODE -eq 0) {
    Write-Host "Données de timezone chargées avec succès." -ForegroundColor Green
} else {
    Write-Host "Erreur lors du chargement des données de timezone." -ForegroundColor Red
    exit 1
}

# Nettoyer les fichiers temporaires
Remove-Item -Path $tzDataFile -Force -ErrorAction SilentlyContinue
docker exec mariadb rm -rf /tmp/tzdata*

Write-Host "`nÉtape 2 : Attribution des droits à l'utilisateur GLPI..." -ForegroundColor Cyan

# Accorder les droits SELECT sur mysql.time_zone_name à l'utilisateur glpi
$grantQuery = @"
GRANT SELECT ON mysql.time_zone_name TO 'glpi'@'%';
FLUSH PRIVILEGES;
"@

Write-Host "Attribution des droits SELECT sur mysql.time_zone_name à l'utilisateur glpi..." -ForegroundColor Yellow
docker exec -i mariadb mysql -uroot -p"$rootPasswordPlain" -e "$grantQuery"

if ($LASTEXITCODE -eq 0) {
    Write-Host "Droits accordés avec succès." -ForegroundColor Green
} else {
    Write-Host "Erreur lors de l'attribution des droits." -ForegroundColor Red
    exit 1
}

Write-Host "`nÉtape 3 : Vérification de la configuration..." -ForegroundColor Cyan

# Vérifier que les timezones sont bien chargées
$checkQuery = "SELECT COUNT(*) as count FROM mysql.time_zone_name;"
$result = docker exec -i mariadb mysql -uroot -p"$rootPasswordPlain" -s -N -e "$checkQuery"

if ($result -gt 0) {
    Write-Host "✓ $result timezones ont été chargées avec succès." -ForegroundColor Green
} else {
    Write-Host "✗ Aucune timezone n'a été trouvée." -ForegroundColor Red
}

# Vérifier les droits de l'utilisateur glpi
Write-Host "`nVérification des droits de l'utilisateur glpi..." -ForegroundColor Yellow
$checkGrantsQuery = "SHOW GRANTS FOR 'glpi'@'%';"
docker exec -i mariadb mysql -uroot -p"$rootPasswordPlain" -e "$checkGrantsQuery"

Write-Host "`n✅ Configuration terminée !" -ForegroundColor Green
Write-Host "Veuillez redémarrer les conteneurs Docker pour appliquer les changements :" -ForegroundColor Yellow
Write-Host "docker-compose restart" -ForegroundColor Cyan

# Nettoyage sécurisé du mot de passe
$rootPasswordPlain = $null
[System.GC]::Collect() 