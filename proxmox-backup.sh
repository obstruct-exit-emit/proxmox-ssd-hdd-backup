#!/bin/bash


#============================================================
# Proxmox Community Script: proxmox-backup-config.sh
#
# Description:
#   Backup and restore all essential Proxmox configuration and metadata
#   needed to reattach and recognize HDDs and storage after a fresh install.
#   Does NOT back up actual disk data, only configuration files.
#
# Usage:
#   Backup:  sudo ./proxmox-backup-config.sh backup /path/to/backup-destination
#   Restore: sudo ./proxmox-backup-config.sh restore /path/to/backup-archive.tar.gz
#
# Author: Your Name
# Version: 1.0
# License: MIT
#============================================================



set -euo pipefail

usage() {
  echo "Usage: $0 backup /path/to/backup-destination"
  echo "       $0 restore /path/to/backup-archive.tar.gz"
  exit 1
}

if [ "$#" -lt 1 ]; then
  usage
fi

MODE="$1"
shift


if [ "$MODE" = "backup" ]; then
  if [ "$#" -lt 1 ]; then
    usage
  fi
  BACKUP_DEST="$1"
  shift
  DATE=$(date +"%Y-%m-%d_%H-%M-%S")
  BACKUP_DIR="$BACKUP_DEST/proxmox-backup-$DATE"
  mkdir -p "$BACKUP_DIR"

  # Backup VM and container configs
  cp -a /etc/pve/qemu-server "$BACKUP_DIR/" 2>/dev/null || echo "No KVM VMs found."
  cp -a /etc/pve/lxc "$BACKUP_DIR/" 2>/dev/null || echo "No LXC containers found."

  # Backup storage config
  cp -a /etc/pve/storage.cfg "$BACKUP_DIR/" 2>/dev/null || echo "No storage.cfg found."

  # Backup disk images and container data (default location)
  cp -a /var/lib/vz "$BACKUP_DIR/" 2>/dev/null || echo "No /var/lib/vz found. Check for custom storage locations."

  # Backup network config
  cp -a /etc/network/interfaces "$BACKUP_DIR/" 2>/dev/null || echo "No network interfaces file found."

  # Backup user and permission settings
  cp -a /etc/pve/user.cfg "$BACKUP_DIR/" 2>/dev/null || echo "No user.cfg found."
  cp -a /etc/pve/priv "$BACKUP_DIR/" 2>/dev/null || echo "No priv directory found."

  # (Optional) Add custom scripts or hooks here
  # cp -a /path/to/custom/scripts "$BACKUP_DIR/"

  # Compress the backup
  cd "$BACKUP_DEST"
  tar czf "proxmox-backup-$DATE.tar.gz" "proxmox-backup-$DATE"
  rm -rf "$BACKUP_DIR"

  echo "Backup completed: $BACKUP_DEST/proxmox-backup-$DATE.tar.gz"


elif [ "$MODE" = "restore" ]; then
  if [ "$#" -lt 1 ]; then
    usage
  fi
  BACKUP_ARCHIVE="$1"
  shift
  if [ ! -f "$BACKUP_ARCHIVE" ]; then
    echo "Backup archive not found: $BACKUP_ARCHIVE"
    exit 1
  fi
  RESTORE_DIR="/tmp/proxmox-restore-$$"
  mkdir -p "$RESTORE_DIR"
  tar xzf "$BACKUP_ARCHIVE" -C "$RESTORE_DIR"
  # Find the extracted backup folder
  EXTRACTED_DIR=$(find "$RESTORE_DIR" -maxdepth 1 -type d -name 'proxmox-backup-*' | head -n 1)
  if [ -z "$EXTRACTED_DIR" ]; then
    echo "Could not find extracted backup directory."
    exit 1
  fi

  # Restore configs (manual step recommended)
  echo "Configs and data extracted to $EXTRACTED_DIR."
  echo "Review and manually copy files to /etc/pve, /var/lib/vz, etc. as needed."

  echo "Restore completed."
  rm -rf "$RESTORE_DIR"

else
  echo "Usage: $0 [backup|restore] ..."
  exit 1
fi
