#!/bin/bash
#-*- coding: UTF8 -*-

#--------------------------------------------------#
# Script_Name: incr_backup.sh
#
# Author:  'dossantosjdf@gmail.com'
# Date: mer. 27 avril 2022 18:43:30
# Update: lun. 20 mai 2024 10:22:02 CEST
# Version: 1.0
# Bash_Version: 5.0.17(1)-release
#--------------------------------------------------#
# Description: Ce script est un outil de sauvegarde de machines distantes.
# Voici les différentes fonctions :
#   * Sauvegarde de fichiers distants à l'aide de Rsync via SSH.
#   * Sauvegarde de type incrémentielle.
#   * Vérifie et attend que la machine soit connectée au réseau pour initier la sauvegarde.
#   * Efface automatiquement les sauvegardes trop anciennes.
#   * Création de logs.
#
# Usage: ./incr_backup.sh
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
# Si erreur 
error_backup() {
  logger -t "$0" "Rsync_Backup --- Erreur pendant la sauvegarde sur la machine $remote_backup_target_ip !"
  exit 0
}

### Variables ###
remote_backup_target_dir="/cygdrive/c/Users/danny/"     # Chemin absolu du répertoire que nous voulons sauvegarder sur la machine distante.
remote_backup_target_ip="192.168.1.22"
remote_backup_target_user="danny"
remote_backup_target_port="22"
remote_backup_target_name="PC_desktop"                  # Nom de la machine a sauvegarder.

all_backups_dir="${HOME}/.rsync_backups/$remote_backup_target_name"  # Chemin où se trouvent toutes les sauvegardes de la machine distante.
latest_link="${all_backups_dir}/.latest"                # Chemin du lien symbolique qui pointe toujours vers la dernière sauvegarde.
backup_dir="$(date '+%F_%H-%M-%S')"
current_date="$(echo "$backup_dir" | cut -d'_' -f1)"
backup_log_file="${backup_dir}.log"                     # Nom du fichier de log.
all_backups_log_dir="$all_backups_dir/logs"             # Chemin du dossier contenant les logs.

# Exemples, supprime les sauvegarde anciennes de plus de ... ou égal à ...
# 3 jours    : '3 days'
# 4 semaines : '4 weeks'
# 2 mois     : '2 months'
# 1 ans      : '1 years'
remove_old_backups='6 months'

# Limitation de la band passante à 8mo/s maximum 
limit_band="8m" 

date_old_backups="$(date --date="$(date --date="$current_date - $remove_old_backups" +%Y-%m-%d)" +%s)"
delbackups=""

# Temps en secondes entre chaque ping.
time_interval_ping="900"

### Main ###
# ERR : Quand une commande échoue.
trap error_backup ERR

# Teste si la machine distante est connecté au réseau.
while ! ping -c 1 -n -w 2 -q "$remote_backup_target_ip" &> /dev/null
do
  logger -t "$0" "Rsync_Backup --- la machine $remote_backup_target_ip est DOWN !"
  sleep "$time_interval_ping"
done

logger -t "$0" "Rsync_Backup --- Début de la sauvegarde sur la machine $remote_backup_target_ip !"

# Création des différents dossiers
# ~/.rsync_backups
# ~/.rsync_backups/[nom machine]
# ~/.rsync_backups/[nom machine]/logs
if [ ! -d "$all_backups_log_dir" ]
then
  mkdir -p "$all_backups_log_dir"
fi

# --delete : Les fichiers supprimés sur la source n'apparaitront pas sur la destination.
# --ignore-errors : Efface même s'il y a eu des erreurs E/S.
# --link-dest : Répertoire utilisé pour la comparaison avec le répertoire source.
# --bwlimit : Limite la bande passante.
rsync --archive -e "ssh -p $remote_backup_target_port" \
 --quiet \
 --delete \
 --ignore-errors \
 --no-links \
 --bwlimit="$limit_band" \
 --include={"Applications/***","Documents/***","Music/***","Nextcloud/***","Pictures/***","Vidéos/***"} \
 --exclude="*" \
 --link-dest="$latest_link" \
 "${remote_backup_target_user}"@"${remote_backup_target_ip}":"${remote_backup_target_dir}" "$all_backups_dir/$backup_dir" \
 --log-file="$all_backups_log_dir/$backup_log_file"

sleep 5

# Création du nouveau lien vers la dernière sauvegarde.
ln -s "$all_backups_dir/$backup_dir" "$latest_link"

# Supprimer les sauvegardes trop anciennes.
mapfile -t liste_backup_files < <(ls --ignore="logs" "$all_backups_dir")

for bakfile in "${liste_backup_files[@]}"
do
  file_date="$(echo "$bakfile" | cut -d'_' -f1)"
  file_date_sec="$(date --date="$file_date" +%s)"

  if [ "$file_date_sec" -le "$date_old_backups" ]
  then
    if [ -n "$all_backups_dir" ] && [ -n "$file_date" ]
    then
      rm -rf "$all_backups_dir/${file_date}*"
    fi
    delbackups+="$file_date"
  fi
done
# Pour consulter les logs : "sudo grep 'Rsync_Backup' /var/log/syslog" ou  "journalctl --grep='Rsync_Backup'"
logger -t "$0" "Rsync_Backup --- Fin de la sauvegarde sur la machine $remote_backup_target_ip !"
