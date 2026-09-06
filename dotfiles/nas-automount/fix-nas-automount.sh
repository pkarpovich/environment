#!/bin/bash
if ! grep -q "auto_nas" /etc/auto_master; then
  echo '/mnt/nas                auto_nas   -nosuid,nodev' >> /etc/auto_master
  automount -vc
fi
mkdir -p /mnt/nas
