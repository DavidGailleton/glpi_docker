#!/bin/bash
# Script de vérification du statut des timezones dans MariaDB pour GLPI

echo -e "\e[36m=== Vérification du statut des timezones MariaDB ===\e[0m"
echo

# Détecter la commande MySQL/MariaDB
MYSQL_CMD=""
if docker compose exec -T mariadb which mariadb >/dev/null 2>&1; then
    MYSQL_CMD="mariadb"
elif docker compose exec -T mariadb which mysql >/dev/null 2>&1; then
    MYSQL_CMD="mysql"
else
    echo -e "\e[31m✗ Aucune commande MySQL/MariaDB trouvée\e[0m"
    exit 1
fi

echo -e "\e[33mVeuillez entrer le mot de passe root de MariaDB :\e[0m"
read -s ROOT_PASSWORD
echo

# Vérifier le nombre de timezones
echo -e "\n\e[36m1. Nombre de timezones dans la base de données :\e[0m"
TZ_COUNT=$(docker compose exec -T mariadb bash -c "$MYSQL_CMD -uroot -p'${ROOT_PASSWORD}' -s -N -e 'SELECT COUNT(*) FROM mysql.time_zone_name;'" 2>/dev/null || echo "ERREUR")

if [ "$TZ_COUNT" = "ERREUR" ]; then
    echo -e "\e[31m   ✗ Impossible d'accéder aux timezones (mauvais mot de passe ou table inexistante)\e[0m"
else
    if [ "$TZ_COUNT" -gt 0 ]; then
        echo -e "\e[32m   ✓ $TZ_COUNT timezones trouvées\e[0m"
    else
        echo -e "\e[31m   ✗ Aucune timezone dans la base de données\e[0m"
    fi
fi

# Vérifier les droits de l'utilisateur glpi
echo -e "\n\e[36m2. Droits de l'utilisateur 'glpi' sur les timezones :\e[0m"
GRANTS=$(docker compose exec -T mariadb bash -c "$MYSQL_CMD -uroot -p'${ROOT_PASSWORD}' -e \"SHOW GRANTS FOR 'glpi'@'%';\"" 2>/dev/null | grep -i time_zone)

if [ -n "$GRANTS" ]; then
    echo -e "\e[32m   ✓ L'utilisateur glpi a les droits SELECT sur mysql.time_zone_name\e[0m"
    echo "   $GRANTS"
else
    echo -e "\e[31m   ✗ L'utilisateur glpi n'a pas les droits sur mysql.time_zone_name\e[0m"
fi

# Test avec l'utilisateur glpi
echo -e "\n\e[36m3. Test d'accès avec l'utilisateur glpi :\e[0m"
echo -e "\e[33mVeuillez entrer le mot de passe de l'utilisateur glpi :\e[0m"
read -s GLPI_PASSWORD
echo

if docker compose exec -T php bash -c "$MYSQL_CMD -uglpi -p'${GLPI_PASSWORD}' -h mariadb -e 'SELECT COUNT(*) as count FROM mysql.time_zone_name;'" 2>/dev/null; then
    echo -e "\e[32m   ✓ L'utilisateur glpi peut accéder aux timezones\e[0m"
else
    echo -e "\e[31m   ✗ L'utilisateur glpi ne peut pas accéder aux timezones\e[0m"
fi

# Résumé
echo -e "\n\e[36m=== Résumé ===\e[0m"
if [ "$TZ_COUNT" != "ERREUR" ] && [ "$TZ_COUNT" -gt 0 ] && [ -n "$GRANTS" ]; then
    echo -e "\e[32m✓ Les timezones semblent correctement configurées\e[0m"
    echo -e "\e[33mN'oubliez pas de redémarrer les conteneurs et vider le cache GLPI\e[0m"
else
    echo -e "\e[31m✗ Les timezones ne sont pas correctement configurées\e[0m"
    echo -e "\e[33mUtilisez le script configure-timezone-database-simple.sh pour les configurer\e[0m"
fi

# Nettoyage
unset ROOT_PASSWORD
unset GLPI_PASSWORD 