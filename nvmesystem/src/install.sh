#!/usr/bin/env ash
#
# Copyright (C) 2023 PeterSuh-Q3 <https://github.com/PeterSuh-Q3>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# From：jim3ma, https://jim.plus/blog/post/jim/synology-installation-with-nvme-disks-only
#

if [ "${1}" = "early" ]; then
  echo "Installing addon nvmesystem - ${1}"

  [ ! -f "/usr/sbin/sed" ] && cp -vf sed /usr/sbin/sed
  chmod +x /usr/sbin/sed

  # [CREATE][failed] Raidtool initsys
  SO_FILE="/usr/syno/bin/scemd"
  [ ! -f "${SO_FILE}.bak" ] && cp -vf "${SO_FILE}" "${SO_FILE}.bak"
  sed -i "s/4584ed74b7488b4c24083b01/4584ed75b7488b4c24083b01/" "${SO_FILE}"

elif [ "${1}" = "late" ]; then
  echo "Installing addon nvmesystem - ${1}"

  # System volume is assembled with SSD Cache only, please remove SSD Cache and then reboot
  sed -i "s/support_ssd_cache=.*/support_ssd_cache=\"no\"/" /tmpRoot/etc/synoinfo.conf /tmpRoot/etc.defaults/synoinfo.conf

  # disk/shared_disk_info_enum.c::84 Failed to allocate list in SharedDiskInfoEnum, errno=0x900.
  SO_FILE="/tmpRoot/usr/lib/libhwcontrol.so.1"
  [ ! -f "${SO_FILE}.bak" ] && cp -vf "${SO_FILE}" "${SO_FILE}.bak"

  sed -i "s/0f95c00fb6c0488b9424081000006448/0f94c00fb6c0488b9424081000006448/; s/ffff89c18944240c8b44240809e84409/ffff89c18944240c8b44240890904409/" "${SO_FILE}"

  # Create storage pool page without RAID type.
  cp -vf nvmesystem.sh /tmpRoot/usr/sbin/nvmesystem.sh
  chmod +x /tmpRoot/usr/sbin/nvmesystem.sh

#  [ ! -f "/tmpRoot/usr/bin/gzip" ] && cp -vf gzip /tmpRoot/usr/bin/gzip
#  chmod +x /tmpRoot/usr/bin/gzip

  cat > /tmpRoot/etc/systemd/system/nvmesystem.service <<'EOF'
[Unit]
Description=Modify storage panel, from wjz304
After=multi-user.target
After=synoscgi.service
After=storagepanel.service
[Service]
Type=oneshot
RemainAfterExit=true
ExecStart=/usr/sbin/nvmesystem.sh
[Install]
WantedBy=multi-user.target
EOF

  mkdir -vp /tmpRoot/etc/systemd/system/multi-user.target.wants
  ln -vsf /etc/systemd/system/nvmesystem.service /tmpRoot/etc/systemd/system/multi-user.target.wants/nvmesystem.service

fi
