#!/usr/bin/env pwsh
# Script alternatif pour configurer les timezones dans MariaDB pour GLPI
# Utilise les données de timezone du système Linux dans le conteneur

Write-Host "Configuration des timezones MariaDB pour GLPI (méthode Linux)" -ForegroundColor Green
Write-Host "=============================================================" -ForegroundColor Green

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

Write-Host "`nÉtape 1 : Installation du package tzdata dans le conteneur..." -ForegroundColor Cyan

# Installer tzdata dans le conteneur MariaDB s'il n'est pas présent
docker exec mariadb bash -c "apt-get update && apt-get install -y tzdata"

Write-Host "`nÉtape 2 : Chargement des données de timezone depuis le système..." -ForegroundColor Cyan

# Charger les données de timezone depuis /usr/share/zoneinfo
$loadTzCommand = @"
mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -uroot -p'$rootPasswordPlain' mysql
"@

Write-Host "Chargement des données de timezone..." -ForegroundColor Yellow
docker exec -i mariadb bash -c $loadTzCommand

if ($LASTEXITCODE -eq 0) {
    Write-Host "Données de timezone chargées avec succès." -ForegroundColor Green
} else {
    Write-Host "Erreur lors du chargement des données de timezone." -ForegroundColor Red
    Write-Host "Tentative avec une méthode alternative..." -ForegroundColor Yellow
    
    # Méthode alternative si mysql_tzinfo_to_sql échoue
    $altCommand = @"
mysql -uroot -p'$rootPasswordPlain' -e "CALL mysql.mariadb_tzinfo_reload();" 2>/dev/null || echo "Méthode alternative non disponible"
"@
    docker exec -i mariadb bash -c $altCommand
}

Write-Host "`nÉtape 3 : Attribution des droits à l'utilisateur GLPI..." -ForegroundColor Cyan

# Accorder les droits SELECT sur mysql.time_zone_name à l'utilisateur glpi
$grantCommands = @"
mysql -uroot -p'$rootPasswordPlain' -e "GRANT SELECT ON mysql.time_zone_name TO 'glpi'@'%';"
mysql -uroot -p'$rootPasswordPlain' -e "FLUSH PRIVILEGES;"
"@

Write-Host "Attribution des droits SELECT sur mysql.time_zone_name à l'utilisateur glpi..." -ForegroundColor Yellow
docker exec -i mariadb bash -c $grantCommands

if ($LASTEXITCODE -eq 0) {
    Write-Host "Droits accordés avec succès." -ForegroundColor Green
} else {
    Write-Host "Erreur lors de l'attribution des droits." -ForegroundColor Red
    exit 1
}

Write-Host "`nÉtape 4 : Vérification de la configuration..." -ForegroundColor Cyan

# Vérifier que les timezones sont bien chargées
$checkCommand = @"
mysql -uroot -p'$rootPasswordPlain' -s -N -e "SELECT COUNT(*) FROM mysql.time_zone_name;"
"@
$tzCount = docker exec -i mariadb bash -c $checkCommand

if ($tzCount -gt 0) {
    Write-Host "✓ $tzCount timezones ont été chargées avec succès." -ForegroundColor Green
} else {
    Write-Host "✗ Aucune timezone n'a été trouvée." -ForegroundColor Red
}

# Vérifier les droits de l'utilisateur glpi
Write-Host "`nVérification des droits de l'utilisateur glpi..." -ForegroundColor Yellow
$checkGrantsCommand = @"
mysql -uroot -p'$rootPasswordPlain' -e "SHOW GRANTS FOR 'glpi'@'%';" | grep -i time_zone
"@
docker exec -i mariadb bash -c $checkGrantsCommand

# Test final : vérifier que l'utilisateur glpi peut accéder aux timezones
Write-Host "`nTest d'accès avec l'utilisateur glpi..." -ForegroundColor Yellow
Write-Host "Veuillez entrer le mot de passe de l'utilisateur glpi :" -ForegroundColor Yellow
$glpiPassword = Read-Host -AsSecureString
$glpiPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($glpiPassword))

$testCommand = @"
mysql -uglpi -p'$glpiPasswordPlain' -h mariadb -e "SELECT COUNT(*) as 'Nombre de timezones accessibles' FROM mysql.time_zone_name;" 2>&1
"@
docker exec -i php bash -c $testCommand

Write-Host "`n✅ Configuration terminée !" -ForegroundColor Green
Write-Host "Veuillez redémarrer les conteneurs Docker pour appliquer complètement les changements :" -ForegroundColor Yellow
Write-Host "docker-compose restart" -ForegroundColor Cyan

# Nettoyage sécurisé des mots de passe
$rootPasswordPlain = $null
$glpiPasswordPlain = $null
[System.GC]::Collect() 