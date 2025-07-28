# Résolution de l'erreur "Access to timezone database (mysql) is not allowed" dans GLPI

## 🚀 Guide rapide

Pour résoudre rapidement l'erreur des timezones :

**Sur Linux/macOS :**
```bash
chmod +x configure-timezone-database-simple.sh
./configure-timezone-database-simple.sh
```

**Sur Windows (PowerShell) :**
```powershell
.\configure-timezone-database-simple.ps1
```

Puis redémarrez et videz le cache :
```bash
docker compose restart
docker compose exec php rm -rf /var/www/html/files/_cache/*
```

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

1. **`configure-timezone-database-simple.ps1`** (🆕 Recommandé pour Windows)
   - Détection automatique des commandes mariadb/mysql
   - Compatible avec docker compose
   - Gestion intelligente des erreurs

2. **`configure-timezone-database-simple.sh`** (🆕 Recommandé pour Linux/macOS)
   - Détection automatique des commandes mariadb/mysql
   - Compatible avec docker compose
   - Gestion intelligente des erreurs

3. **`configure-timezone-database.sh`** (Pour Linux/macOS - Version alternative)
   - Script bash mis à jour qui utilise les commandes mariadb
   - Compatible avec docker compose

3. **`configure-timezone-database-linux.ps1`** (Alternative pour Windows)
   - Version plus ancienne, utiliser si le script simple échoue

4. **`configure-timezone-database.ps1`** (Archive)
   - Version originale avec téléchargement des données

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
   .\configure-timezone-database-simple.ps1
   ```

4. Suivez les instructions :
   - Entrez le mot de passe root de MariaDB quand demandé

5. Une fois le script terminé, suivez les actions recommandées affichées :
   ```powershell
   docker compose restart
   docker compose exec php rm -rf /var/www/html/files/_cache/*
   ```

### Étapes pour Linux/macOS

1. Rendez le script exécutable :
   ```bash
   chmod +x configure-timezone-database-simple.sh
   ```

2. Exécutez le script :
   ```bash
   ./configure-timezone-database-simple.sh
   ```

3. Suivez les instructions :
   - Entrez le mot de passe root de MariaDB quand demandé

4. Suivez les actions recommandées affichées :
   ```bash
   docker compose restart
   docker compose exec php rm -rf /var/www/html/files/_cache/*
   ```

## Ce que font les scripts

Les scripts effectuent automatiquement les actions suivantes :

1. **Installation de tzdata** dans le conteneur MariaDB
2. **Chargement des données de timezone** depuis `/usr/share/zoneinfo`
3. **Attribution des droits** `SELECT` sur `mysql.time_zone_name` à l'utilisateur `glpi`
4. **Vérification** que tout fonctionne correctement

## Vérification

### Script de vérification automatique

Un script de vérification rapide est disponible :

```bash
chmod +x check-timezone-status.sh
./check-timezone-status.sh
```

Ce script vérifie automatiquement :
- Le nombre de timezones chargées
- Les droits de l'utilisateur glpi
- L'accès effectif aux timezones

### Vérification manuelle (optionnel)

Si vous souhaitez vérifier manuellement :

1. Connectez-vous au conteneur MariaDB :
   ```bash
   docker compose exec mariadb mariadb -uroot -p
   ```

2. Vérifiez le nombre de timezones :
   ```sql
   SELECT COUNT(*) FROM mysql.time_zone_name;
   ```

3. Vérifiez les droits de l'utilisateur glpi :
   ```sql
   SHOW GRANTS FOR 'glpi'@'%';
   ```

## Dépannage

### Erreur "mysql: command not found" ou "mariadb: command not found"

Cette erreur se produit car les nouvelles images MariaDB utilisent la commande `mariadb` au lieu de `mysql`. Les scripts mis à jour gèrent automatiquement cette différence.

**Solution :**
- Utilisez le script `configure-timezone-database-simple.ps1` (Windows) ou la version mise à jour de `configure-timezone-database.sh` (Linux/macOS)

### Si le script échoue au chargement des timezones

1. Vérifiez que les conteneurs sont bien lancés avec `docker compose ps`
2. Assurez-vous que le mot de passe root est correct
3. Essayez de vous connecter manuellement pour diagnostiquer :
   ```bash
   docker compose exec mariadb mariadb -uroot -p
   ```

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