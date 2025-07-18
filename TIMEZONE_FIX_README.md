# Résolution de l'erreur "Access to timezone database (mysql) is not allowed" dans GLPI

## Description du problème

GLPI affiche l'erreur suivante dans les informations système :
```
Access to timezone database (mysql) is not allowed.
```

Cette erreur indique que :
1. Les données de timezone ne sont pas chargées dans MariaDB
2. L'utilisateur GLPI (`glpi`) n'a pas les droits d'accès nécessaires sur la table `mysql.time_zone_name`

## Solution

J'ai créé plusieurs scripts pour résoudre ce problème :

### Scripts disponibles

1. **`configure-timezone-database-linux.ps1`** (Recommandé pour Windows)
   - Utilise les données de timezone du système Linux dans le conteneur
   - Méthode la plus fiable

2. **`configure-timezone-database.ps1`** (Alternative pour Windows)
   - Télécharge les données de timezone depuis MariaDB
   - Utiliser si la première méthode échoue

3. **`configure-timezone-database.sh`** (Pour Linux/macOS)
   - Script bash équivalent

## Instructions d'utilisation

### Prérequis

1. Assurez-vous que vos conteneurs Docker sont en cours d'exécution :
   ```powershell
   docker-compose up -d
   ```

2. Vous devez connaître :
   - Le mot de passe root de MariaDB
   - Le mot de passe de l'utilisateur `glpi`

### Étapes pour Windows (PowerShell)

1. Ouvrez PowerShell en tant qu'administrateur

2. Naviguez vers le répertoire de votre projet :
   ```powershell
   cd C:\Users\David.GAILLETON\Dev\glpi_docker
   ```

3. Exécutez le script recommandé :
   ```powershell
   .\configure-timezone-database-linux.ps1
   ```

4. Suivez les instructions :
   - Entrez le mot de passe root de MariaDB
   - Entrez le mot de passe de l'utilisateur glpi (pour le test final)

5. Une fois le script terminé, redémarrez les conteneurs :
   ```powershell
   docker-compose restart
   ```

### Étapes pour Linux/macOS

1. Rendez le script exécutable :
   ```bash
   chmod +x configure-timezone-database.sh
   ```

2. Exécutez le script :
   ```bash
   ./configure-timezone-database.sh
   ```

3. Suivez les mêmes instructions que pour Windows

## Ce que font les scripts

Les scripts effectuent automatiquement les actions suivantes :

1. **Installation de tzdata** dans le conteneur MariaDB
2. **Chargement des données de timezone** depuis `/usr/share/zoneinfo`
3. **Attribution des droits** `SELECT` sur `mysql.time_zone_name` à l'utilisateur `glpi`
4. **Vérification** que tout fonctionne correctement

## Vérification manuelle (optionnel)

Si vous souhaitez vérifier manuellement :

1. Connectez-vous au conteneur MariaDB :
   ```bash
   docker exec -it mariadb bash
   ```

2. Vérifiez le nombre de timezones :
   ```sql
   mysql -uroot -p
   SELECT COUNT(*) FROM mysql.time_zone_name;
   ```

3. Vérifiez les droits de l'utilisateur glpi :
   ```sql
   SHOW GRANTS FOR 'glpi'@'%';
   ```

## Dépannage

### Si le script échoue au chargement des timezones

1. Essayez l'autre script PowerShell (`configure-timezone-database.ps1`)
2. Vérifiez que le conteneur MariaDB est bien en cours d'exécution
3. Assurez-vous que le mot de passe root est correct

### Si l'erreur persiste après l'exécution du script

1. Vérifiez les logs de GLPI
2. Assurez-vous d'avoir bien redémarré les conteneurs
3. Effacez le cache de GLPI :
   ```bash
   docker exec -it php rm -rf /var/www/html/files/_cache/*
   ```

## Notes importantes

- Les timezones sont nécessaires pour certaines fonctionnalités avancées de GLPI
- Cette configuration n'affecte que la base de données GLPI
- Les scripts nettoient automatiquement les mots de passe de la mémoire après utilisation 