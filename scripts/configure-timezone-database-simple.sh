#!/bin/bash
# Script simplifié pour configurer les timezones dans MariaDB pour GLPI
# Compatible avec docker compose et les commandes mariadb/mysql

set -e

echo -e "\e[32mConfiguration des timezones MariaDB pour GLPI (version simplifiée)\e[0m"
echo -e "\e[32m==================================================================\e[0m"

# Vérifier que Docker Compose est en cours d'exécution
echo -e "\n\e[33mVérification des conteneurs Docker...\e[0m"
if ! docker compose ps 2>/dev/null | grep -q "mariadb.*running"; then
    echo -e "\e[31mErreur : Le conteneur MariaDB n'est pas en cours d'exécution.\e[0m"
    echo -e "\e[33mVeuillez d'abord lancer Docker Compose avec : docker compose up -d\e[0m"
    exit 1
fi

# Afficher les conteneurs actifs
echo -e "\e[36mConteneurs actifs :\e[0m"
docker compose ps

# Demander le mot de passe root MariaDB
echo -e "\n\e[33mVeuillez entrer le mot de passe root de MariaDB :\e[0m"
read -s MYSQL_ROOT_PASSWORD
echo

echo -e "\n\e[36mÉtape 1 : Détection de la commande MySQL/MariaDB...\e[0m"

# Détecter quelle commande utiliser
MYSQL_CMD=""
if docker compose exec -T mariadb which mariadb >/dev/null 2>&1; then
    MYSQL_CMD="mariadb"
    echo -e "\e[32m✓ Commande 'mariadb' détectée\e[0m"
elif docker compose exec -T mariadb which mysql >/dev/null 2>&1; then
    MYSQL_CMD="mysql"
    echo -e "\e[32m✓ Commande 'mysql' détectée\e[0m"
else
    echo -e "\e[31m✗ Aucune commande MySQL/MariaDB trouvée dans le conteneur\e[0m"
    exit 1
fi

echo -e "\n\e[36mÉtape 2 : Installation de tzdata...\e[0m"
docker compose exec -T mariadb bash -c "apt-get update >/dev/null 2>&1 && apt-get install -y tzdata >/dev/null 2>&1"
echo -e "\e[32m✓ Package tzdata installé\e[0m"

echo -e "\n\e[36mÉtape 3 : Chargement des données de timezone...\e[0m"

# Charger les timezones
LOADED=false

# Méthode 1 : mariadb-tzinfo-to-sql
if docker compose exec -T mariadb bash -c "command -v mariadb-tzinfo-to-sql >/dev/null 2>&1"; then
    echo -e "\e[33mUtilisation de mariadb-tzinfo-to-sql...\e[0m"
    if docker compose exec -T mariadb bash -c "mariadb-tzinfo-to-sql /usr/share/zoneinfo | $MYSQL_CMD -uroot -p'${MYSQL_ROOT_PASSWORD}' mysql" 2>/dev/null; then
        LOADED=true
    fi
fi

# Méthode 2 : mysql_tzinfo_to_sql
if [ "$LOADED" = false ] && docker compose exec -T mariadb bash -c "command -v mysql_tzinfo_to_sql >/dev/null 2>&1"; then
    echo -e "\e[33mUtilisation de mysql_tzinfo_to_sql...\e[0m"
    if docker compose exec -T mariadb bash -c "mysql_tzinfo_to_sql /usr/share/zoneinfo | $MYSQL_CMD -uroot -p'${MYSQL_ROOT_PASSWORD}' mysql" 2>/dev/null; then
        LOADED=true
    fi
fi

# Méthode 3 : Chargement manuel
if [ "$LOADED" = false ]; then
    echo -e "\e[33mEssai de chargement manuel...\e[0m"
    # Essayer de charger depuis un fichier SQL pré-existant
    if docker compose exec -T mariadb bash -c "$MYSQL_CMD -uroot -p'${MYSQL_ROOT_PASSWORD}' mysql -e 'SOURCE /usr/share/mysql/mysql_test_data_timezone.sql;'" 2>/dev/null; then
        LOADED=true
    # Ou essayer la fonction MariaDB
    elif docker compose exec -T mariadb bash -c "$MYSQL_CMD -uroot -p'${MYSQL_ROOT_PASSWORD}' -e 'CALL mysql.mariadb_tzinfo_reload();'" 2>/dev/null; then
        LOADED=true
    fi
fi

if [ "$LOADED" = true ]; then
    echo -e "\e[32m✓ Données de timezone chargées avec succès\e[0m"
else
    echo -e "\e[31m✗ Impossible de charger les timezones automatiquement\e[0m"
    echo -e "\e[33mVous devrez peut-être les charger manuellement\e[0m"
fi

echo -e "\n\e[36mÉtape 4 : Attribution des droits à l'utilisateur GLPI...\e[0m"

# Accorder les droits
if docker compose exec -T mariadb bash -c "
    $MYSQL_CMD -uroot -p'${MYSQL_ROOT_PASSWORD}' -e \"GRANT SELECT ON mysql.time_zone_name TO 'glpi'@'%';\" && \
    $MYSQL_CMD -uroot -p'${MYSQL_ROOT_PASSWORD}' -e \"FLUSH PRIVILEGES;\"
" 2>/dev/null; then
    echo -e "\e[32m✓ Droits accordés avec succès\e[0m"
else
    echo -e "\e[31m✗ Erreur lors de l'attribution des droits\e[0m"
fi

echo -e "\n\e[36mÉtape 5 : Vérification finale...\e[0m"

# Vérifier le nombre de timezones
TZ_COUNT=$(docker compose exec -T mariadb bash -c "$MYSQL_CMD -uroot -p'${MYSQL_ROOT_PASSWORD}' -s -N -e 'SELECT COUNT(*) FROM mysql.time_zone_name;'" 2>/dev/null || echo "0")

if [ "$TZ_COUNT" -gt 0 ]; then
    echo -e "\e[32m✓ $TZ_COUNT timezones ont été chargées\e[0m"
else
    echo -e "\e[31m✗ Aucune timezone trouvée dans la base de données\e[0m"
fi

# Afficher les droits de l'utilisateur glpi
echo -e "\n\e[33mDroits de l'utilisateur 'glpi' :\e[0m"
docker compose exec -T mariadb bash -c "$MYSQL_CMD -uroot -p'${MYSQL_ROOT_PASSWORD}' -e \"SHOW GRANTS FOR 'glpi'@'%';\"" 2>/dev/null | grep -i time_zone || echo "Aucun droit time_zone trouvé"

echo -e "\n\e[32m✅ Configuration terminée !\e[0m"
echo -e "\n\e[33mActions recommandées :\e[0m"
echo -e "\e[36m1. Redémarrez les conteneurs : docker compose restart\e[0m"
echo -e "\e[36m2. Videz le cache GLPI : docker compose exec php rm -rf /var/www/html/files/_cache/*\e[0m"
echo -e "\e[36m3. Reconnectez-vous à GLPI et vérifiez dans Setup > General > System information\e[0m"

# Nettoyage des variables
unset MYSQL_ROOT_PASSWORD 