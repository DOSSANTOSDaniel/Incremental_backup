#!/bin/bash
#-*- coding: UTF8 -*-

#--------------------------------------------------#
# Script_Name: incr_backup.bash
#
# Author:  'dossantosjdf@gmail.com'
# Date: ven. 22 avril 2022 18:43:30
# Version: 1.0
# Bash_Version: 5.0.17(1)-release
#--------------------------------------------------#
# Description:
#https://linuxconfig.org/how-to-create-incremental-backups-using-rsync-on-linux
#
# Options:
#
# Usage: ./incr_backup.bash
#
# Limits:
#
# Licence:
#--------------------------------------------------#

set -o errexit
set -o nounset
set -o pipefail

### Fonctions ###
error_backup() {
  rm -rf $backup_path
  exit 0
}

### Global variables ###
readonly source_dir="/home/daniel/Documents"      # Chemin absolu du répertoire que nous voulons sauvegarder sur la machine distante.
readonly source_ip="192.168.1.48"
readonly source_user="daniel"
readonly source_port="22"

readonly backup_dir="${HOME}/.backup_PC_desktop"  # Chemin où se trouvent toutes les sauvegardes sur la machine locale.
readonly datetime="$(date '+%Y-%m-%d_%H-%M-%S')"
readonly backup_path="${backup_dir}/${datetime}"  # Chemin absolu du répertoire de sauvegarde pour chaque sauvegarde sur la machine locale.
readonly latest_link="${backup_dir}/.latest"      # Chemin du lien symbolique qui pointe toujours vers la dernière sauvegarde sur la machine locale.

### Main ###
trap error_backup ERR EXIT

mkdir -p "${backup_dir}/logs"

# -m
# --delete
# --ignore-errors : efface même s'il y a eu des erreurs E/S
# --link-dest

rsync -a -m -e "ssh -p $source_port"\
 --quiet --delete --ignore-errors --link-dest="$latest_link"\
 --exclude={"*~",".cache",".config",".mozilla","*.swp","*.swo"}\
 ${source_user}@${source_ip}:${source_dir}/ $backup_path\
 --log-file="${backup_dir}/logs/${datetime}.log"

rm -rf $latest_link
sleep 10
ln -s $backup_path $latest_link
