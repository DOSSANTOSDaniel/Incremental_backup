#!/bin/bash
#-*- coding: UTF8 -*-

#--------------------------------------------------#
# Script_Name: incr_backup.sh
#
# Author:  'dossantosjdf@gmail.com'
# Date: mer. 27 avril 2022 18:43:30
# Version: 1.0
# Bash_Version: 5.0.17(1)-release
#--------------------------------------------------#
# Description:
#
# Options:
#
# Usage: ./incr_backup.sh
#
# Limits:
#
# Licence:
#
# Sources:
# https://se.ifmo.ru/~ad/Documentation/Shells_by_Example/ch12lev1sec9.html
# https://linuxconfig.org/how-to-create-incremental-backups-using-rsync-on-linux
# https://www.ionos.fr/digitalguide/serveur/configuration/commande-in-de-linux/
# man 7 signal
# man rsync
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
readonly source_dir="/home/daniel/Images"      # Chemin absolu du répertoire que nous voulons sauvegarder sur la machine distante.
readonly source_ip="192.168.1.48"
readonly source_user="daniel"
readonly source_port="22"

readonly backup_dir="${HOME}/.rsync_backups/backup_PC_desktop"  # Chemin où se trouvent toutes les sauvegardes sur la machine locale.
readonly datetime="$(date '+%Y-%m-%d_%H-%M-%S')"
readonly backup_path="${backup_dir}/${datetime}"  # Chemin absolu du répertoire de sauvegarde pour chaque sauvegarde sur la machine locale.
readonly latest_link="${backup_dir}/.latest"      # Chemin du lien symbolique qui pointe toujours vers la dernière sauvegarde sur la machine locale.

### Main ###
# ERR : Quand une commande échoue avec un statu autre que 0
trap error_backup ERR

mkdir -p "${backup_dir}/logs"

# --delete : Les fichiers supprimés sur la source n'apparaitront pas sur la destination.
# --ignore-errors : Efface même s'il y a eu des erreurs E/S.
# --link-dest : Répertoire utilisé pour la comparaison avec le répertoire source.

rsync -aq -e "ssh -p $source_port"\
 --quiet --delete --ignore-errors --link-dest="$latest_link"\
 --include={".ssh",".config",".bashrc"}\
 --exclude={"*~",".*"}\
 ${source_user}@${source_ip}:${source_dir}/ $backup_path\
 --log-file="${backup_dir}/logs/${datetime}.log"

rm -rf $latest_link

sleep 5

ln -s $backup_path $latest_link
