#!/bin/bash
# update Nextcloud docker compose service
# RDBMS: Postgres

# global variables
newPostgresVersion="${1}"
# check positional parameter $1
if [[ -z "${newPostgresVersion}" ]]; then
  echo -e "You have to provide the new postgres version!!!\nFormat: [ 15_2 ]"
  exit 1
fi
serviceDir='/home/anymus/services/nextcloud'
composeFilePath="${serviceDir}/docker-compose.yml"
# check if service dir and compose file exist
if [ ! -d "${serviceDir}" ] && [ ! -f "${composeFilePath}" ]; then
  echo -e "the service path: \"${serviceDir}\" is invalid!"
  exit 1
fi
logFile="${serviceDir}/scripts/updateError.log"
currentDate="$(date '+%Y-%m-%d-%H-%M-%S')"

function update {
  # variables
  local postgresContainer='nextcloud-db-1'
  local composeProjectName='nextcloud'
  local newVolumeNameFormat="nextcloud-db-${newPostgresVersion}"
  local newVolumeName="${newVolumeNameFormat}-vol"
  local newVolumeDevice="/ssd-pool/${newVolumeNameFormat}"
  local postgresUser="anymus"
  local sqlExportPath="/tmp/nxtcloud_export_${currentDate}.sql"
  # create new directory and docker volume
  mkdir -p "${newVolumeDevice}"
  docker volume create --driver local --opt type=btrfs --opt o=bind --opt device="${newVolumeDevice}" "${newVolumeName}"
  if [[ "${?}" -ne 0 ]]; then
    return 1
  fi
  # export postgres
  docker exec -it "${postgresContainer}" pg_dumpall -U "${postgresUser}" >"${sqlExportPath}"
  if [[ "${?}" -ne 0 ]]; then
    return 1
  fi
  # update the compose file with the new volume
  sed \
    -i.bak \
    "s/nextcloud-db-[0-9]*_[0-9]*-vol:/${newVolumeName}:/g" "${composeFilePath}"
  # pull latest images and turn on the nextcloud compose service
  docker compose -f "${composeFilePath}" -p "${composeProjectName}" pull
  if [[ "${?}" -ne 0 ]]; then
    return 1
  fi
  docker compose -f "${composeFilePath}" -p "${composeProjectName}" down
  sleep 4
  docker compose -f "${composeFilePath}" -p "${composeProjectName}" up -d
  if [[ "${?}" -ne 0 ]]; then
    return 1
  fi
  echo -e "Turning containers on:\n"
  sleep 4
  # import the exported SQL into the new postgres database
  docker cp "${sqlExportPath}" "${postgresContainer}":"${sqlExportPath}"
  sleep 4
  docker exec -it "${postgresContainer}" psql -U "${postgresUser}" -f "${sqlExportPath}"
  if [[ "${?}" -ne 0 ]]; then
    return 1
  fi
  sleep 4
  docker exec -u 33 -it nextcloud-web-1 bash -c '/var/www/html/occ upgrade'
  if [[ "${?}" -ne 0 ]]; then
    return 1
  fi

  return 0
}

function MAIN {
  update
  if [[ "${?}" -ne 0 ]]; then
    echo -e "${currentDate}\nError updating the Nextcloud service from function \"update\"\n\n" >>"${logFile}"
    exit 1
  fi
  echo "Nextcloud service upgrade was a SUCCESS!"
  exit 0
}

MAIN
