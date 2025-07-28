#!/usr/bin/env pwsh
# Script simplifié pour configurer les timezones dans MariaDB pour GLPI
# Compatible avec docker compose et les commandes mariadb/mysql

Write-Host "Configuration des timezones MariaDB pour GLPI (version simplifiée)" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green

# Vérifier que Docker Compose est en cours d'exécution
Write-Host "`nVérification des conteneurs Docker..." -ForegroundColor Yellow
$containers = docker compose ps --format "table {{.Names}}\t{{.Status}}" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Erreur : Docker Compose n'est pas accessible ou les conteneurs ne sont pas lancés." -ForegroundColor Red
    Write-Host "Veuillez d'abord lancer Docker Compose avec : docker compose up -d" -ForegroundColor Yellow
    exit 1
}

# Afficher les conteneurs en cours d'exécution
Write-Host "Conteneurs actifs :" -ForegroundColor Cyan
Write-Host $containers

# Demander le mot de passe root MariaDB
Write-Host "`nVeuillez entrer le mot de passe root de MariaDB :" -ForegroundColor Yellow
$rootPassword = Read-Host -AsSecureString
$rootPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($rootPassword))

Write-Host "`nÉtape 1 : Détection de la commande MySQL/MariaDB..." -ForegroundColor Cyan

# Détecter quelle commande utiliser (mariadb ou mysql)
$mysqlCmd = ""
$testMariadb = docker compose exec -T mariadb bash -c "which mariadb 2>/dev/null" 2>$null
if ($LASTEXITCODE -eq 0) {
    $mysqlCmd = "mariadb"
    Write-Host "✓ Commande 'mariadb' détectée" -ForegroundColor Green
} else {
    $testMysql = docker compose exec -T mariadb bash -c "which mysql 2>/dev/null" 2>$null
    if ($LASTEXITCODE -eq 0) {
        $mysqlCmd = "mysql"
        Write-Host "✓ Commande 'mysql' détectée" -ForegroundColor Green
    } else {
        Write-Host "✗ Aucune commande MySQL/MariaDB trouvée dans le conteneur" -ForegroundColor Red
        exit 1
    }
}

Write-Host "`nÉtape 2 : Installation de tzdata..." -ForegroundColor Cyan
docker compose exec -T mariadb bash -c "apt-get update >/dev/null 2>&1 && apt-get install -y tzdata >/dev/null 2>&1"
Write-Host "✓ Package tzdata installé" -ForegroundColor Green

Write-Host "`nÉtape 3 : Chargement des données de timezone..." -ForegroundColor Cyan

# Essayer de charger les timezones
$tzLoadCommand = @"
if [ -f /usr/share/zoneinfo/zone.tab ]; then
    # Méthode 1 : Utiliser mysql_tzinfo_to_sql ou mariadb-tzinfo-to-sql
    if command -v mariadb-tzinfo-to-sql >/dev/null 2>&1; then
        mariadb-tzinfo-to-sql /usr/share/zoneinfo | $mysqlCmd -uroot -p'$rootPasswordPlain' mysql
    elif command -v mysql_tzinfo_to_sql >/dev/null 2>&1; then
        mysql_tzinfo_to_sql /usr/share/zoneinfo | $mysqlCmd -uroot -p'$rootPasswordPlain' mysql
    else
        # Méthode 2 : Charger manuellement les fichiers SQL si disponibles
        echo "Commandes tzinfo non trouvées, essai de chargement manuel..."
        $mysqlCmd -uroot -p'$rootPasswordPlain' mysql -e "SOURCE /usr/share/mysql/mysql_test_data_timezone.sql;" 2>/dev/null || \
        $mysqlCmd -uroot -p'$rootPasswordPlain' mysql -e "CALL mysql.mariadb_tzinfo_reload();" 2>/dev/null || \
        echo "Impossible de charger les timezones automatiquement"
    fi
else
    echo "Répertoire /usr/share/zoneinfo non trouvé"
    exit 1
fi
"@

Write-Host "Chargement en cours..." -ForegroundColor Yellow
$result = docker compose exec -T mariadb bash -c $tzLoadCommand 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Données de timezone chargées avec succès" -ForegroundColor Green
} else {
    Write-Host "✗ Problème lors du chargement des timezones" -ForegroundColor Red
    Write-Host "Détails : $result" -ForegroundColor DarkGray
}

Write-Host "`nÉtape 4 : Attribution des droits à l'utilisateur GLPI..." -ForegroundColor Cyan

# Accorder les droits
$grantCommand = @"
$mysqlCmd -uroot -p'$rootPasswordPlain' -e "GRANT SELECT ON mysql.time_zone_name TO 'glpi'@'%';" && \
$mysqlCmd -uroot -p'$rootPasswordPlain' -e "FLUSH PRIVILEGES;"
"@

docker compose exec -T mariadb bash -c $grantCommand 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Droits accordés avec succès" -ForegroundColor Green
} else {
    Write-Host "✗ Erreur lors de l'attribution des droits" -ForegroundColor Red
}

Write-Host "`nÉtape 5 : Vérification finale..." -ForegroundColor Cyan

# Vérifier le nombre de timezones
$checkCommand = "$mysqlCmd -uroot -p'$rootPasswordPlain' -s -N -e 'SELECT COUNT(*) FROM mysql.time_zone_name;'"
$tzCount = docker compose exec -T mariadb bash -c $checkCommand 2>$null

if ($tzCount -gt 0) {
    Write-Host "✓ $tzCount timezones ont été chargées" -ForegroundColor Green
} else {
    Write-Host "✗ Aucune timezone trouvée dans la base de données" -ForegroundColor Red
}

# Afficher les droits de l'utilisateur glpi
Write-Host "`nDroits de l'utilisateur 'glpi' :" -ForegroundColor Yellow
$showGrantsCommand = "$mysqlCmd -uroot -p'$rootPasswordPlain' -e `"SHOW GRANTS FOR 'glpi'@'%';`""
docker compose exec -T mariadb bash -c $showGrantsCommand 2>$null | Select-String "time_zone"

Write-Host "`n✅ Configuration terminée !" -ForegroundColor Green
Write-Host "`nActions recommandées :" -ForegroundColor Yellow
Write-Host "1. Redémarrez les conteneurs : docker compose restart" -ForegroundColor Cyan
Write-Host "2. Videz le cache GLPI : docker compose exec php rm -rf /var/www/html/files/_cache/*" -ForegroundColor Cyan
Write-Host "3. Reconnectez-vous à GLPI et vérifiez dans Setup > General > System information" -ForegroundColor Cyan

# Nettoyage sécurisé du mot de passe
$rootPasswordPlain = $null
[System.GC]::Collect() 