#!/bin/bash
# Script pour configurer les timezones dans MariaDB pour GLPI
# Ce script doit être exécuté après que les conteneurs Docker soient en cours d'exécution

set -e

echo -e "\e[32mConfiguration des timezones MariaDB pour GLPI\e[0m"
echo -e "\e[32m=============================================\e[0m"

# Vérifier que Docker Compose est en cours d'exécution
if ! docker ps --filter "name=mariadb" --format "{{.Names}}" | grep -q "mariadb"; then
    echo -e "\e[31mErreur : Le conteneur MariaDB n'est pas en cours d'exécution.\e[0m"
    echo -e "\e[33mVeuillez d'abord lancer Docker Compose avec : docker-compose up -d\e[0m"
    exit 1
fi

# Demander le mot de passe root MariaDB
echo -e "\n\e[33mVeuillez entrer le mot de passe root de MariaDB :\e[0m"
read -s MYSQL_ROOT_PASSWORD
echo

echo -e "\n\e[36mÉtape 1 : Installation du package tzdata dans le conteneur...\e[0m"

# Installer tzdata dans le conteneur MariaDB s'il n'est pas présent
docker compose exec mariadb bash -c "apt-get update > /dev/null 2>&1 && apt-get install -y tzdata > /dev/null 2>&1"

echo -e "\n\e[36mÉtape 2 : Chargement des données de timezone depuis le système...\e[0m"

# Charger les données de timezone depuis /usr/share/zoneinfo
echo -e "\e[33mChargement des données de timezone...\e[0m"
if docker compose exec -i mariadb bash -c "mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -uroot -p'${MYSQL_ROOT_PASSWORD}' mysql"; then
    echo -e "\e[32mDonnées de timezone chargées avec succès.\e[0m"
else
    echo -e "\e[31mErreur lors du chargement des données de timezone.\e[0m"
    echo -e "\e[33mTentative avec une méthode alternative...\e[0m"
    
    # Méthode alternative si mysql_tzinfo_to_sql échoue
    docker compose exec -i mariadb bash -c "mysql -uroot -p'${MYSQL_ROOT_PASSWORD}' -e 'CALL mysql.mariadb_tzinfo_reload();' 2>/dev/null" || echo "Méthode alternative non disponible"
fi

echo -e "\n\e[36mÉtape 3 : Attribution des droits à l'utilisateur GLPI...\e[0m"

# Accorder les droits SELECT sur mysql.time_zone_name à l'utilisateur glpi
echo -e "\e[33mAttribution des droits SELECT sur mysql.time_zone_name à l'utilisateur glpi...\e[0m"
if docker compose exec -i mariadb bash -c "
    mysql -uroot -p'${MYSQL_ROOT_PASSWORD}' -e \"GRANT SELECT ON mysql.time_zone_name TO 'glpi'@'%';\" && \
    mysql -uroot -p'${MYSQL_ROOT_PASSWORD}' -e \"FLUSH PRIVILEGES;\"
"; then
    echo -e "\e[32mDroits accordés avec succès.\e[0m"
else
    echo -e "\e[31mErreur lors de l'attribution des droits.\e[0m"
    exit 1
fi

echo -e "\n\e[36mÉtape 4 : Vérification de la configuration...\e[0m"

# Vérifier que les timezones sont bien chargées
TZ_COUNT=$(docker compose exec -i mariadb bash -c "mysql -uroot -p'${MYSQL_ROOT_PASSWORD}' -s -N -e 'SELECT COUNT(*) FROM mysql.time_zone_name;'" 2>/dev/null)

if [ -n "$TZ_COUNT" ] && [ "$TZ_COUNT" -gt 0 ]; then
    echo -e "\e[32m✓ $TZ_COUNT timezones ont été chargées avec succès.\e[0m"
else
    echo -e "\e[31m✗ Aucune timezone n'a été trouvée.\e[0m"
fi

# Vérifier les droits de l'utilisateur glpi
echo -e "\n\e[33mVérification des droits de l'utilisateur glpi...\e[0m"
docker compose exec -i mariadb bash -c "mysql -uroot -p'${MYSQL_ROOT_PASSWORD}' -e \"SHOW GRANTS FOR 'glpi'@'%';\"" | grep -i time_zone || true

# Test final : vérifier que l'utilisateur glpi peut accéder aux timezones
echo -e "\n\e[33mTest d'accès avec l'utilisateur glpi...\e[0m"
echo -e "\e[33mVeuillez entrer le mot de passe de l'utilisateur glpi :\e[0m"
read -s GLPI_PASSWORD
echo

if docker compose exec -i php bash -c "mysql -uglpi -p'${GLPI_PASSWORD}' -h mariadb -e 'SELECT COUNT(*) as \"Nombre de timezones accessibles\" FROM mysql.time_zone_name;' 2>&1"; then
    echo -e "\n\e[32m✓ L'utilisateur glpi peut accéder aux timezones.\e[0m"
else
    echo -e "\n\e[31m✗ L'utilisateur glpi ne peut pas accéder aux timezones.\e[0m"
fi

echo -e "\n\e[32m✅ Configuration terminée !\e[0m"
echo -e "\e[33mVeuillez redémarrer les conteneurs Docker pour appliquer complètement les changements :\e[0m"
echo -e "\e[36mdocker-compose restart\e[0m"

# Nettoyage des variables
unset MYSQL_ROOT_PASSWORD
unset GLPI_PASSWORD 