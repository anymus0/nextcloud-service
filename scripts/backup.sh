#!/bin/bash

# db backup
currentDate=$(date +"%d-%m-%Y--%H-%M");
sqlBackupPath="/path/to/nextcloud-db-backup-${currentDate}.sql.gz"
docker exec nextcloud-db-1 usr/bin/pg_dump -U anymus nextcloud | gzip -9 > "${sqlBackupPath}"

# sync docker volumes: nextcloud-db, nextcloud-data
rsync -rclptg --delete /path/to/nextcloud* /path/to/nextcloud/

# delete SQL backups older than 7 days
find /path/to/nextcloud/db-dumps -mtime +7 -type f -delete 2> backup_error.log