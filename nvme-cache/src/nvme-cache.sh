#!/bin/sh

echo "Collecting 1st nvme paths"
nvmepath1=$(readlink /sys/class/nvme/nvme0 | sed 's|^.*\(pci.*\)|\1|' | cut -d'/' -f2- | cut -d'/' -f1)
echo "Found local 1st nvme with path $nvmepath1"
if [ $(echo $nvmepath1 | wc -w) -eq 0 ]; then
    echo "Not found local 1st nvme"
    exit 0
else
    hex1=$(readlink /sys/class/nvme/nvme0 | sed 's|^.*\(pci.*\)|\1|' | cut -d'/' -f2- | cut -d'/' -f1 | awk -F ":" '{print $3}' | cut -c 1-1 | xxd  -c 256 -ps | sed "s/..$//")
    hex2=$(readlink /sys/class/nvme/nvme0 | sed 's|^.*\(pci.*\)|\1|' | cut -d'/' -f2- | cut -d'/' -f1 | awk -F ":" '{print $3}' | cut -c 2-2 | xxd  -c 256 -ps | sed "s/..$//")
    hex3=$(readlink /sys/class/nvme/nvme0 | sed 's|^.*\(pci.*\)|\1|' | cut -d'/' -f2- | cut -d'/' -f1 | awk -F ":" '{print $3}' | cut -c 4-4 | xxd  -c 256 -ps | sed "s/..$//")
    nvme1hex=$(echo "3a$hex1 $hex2/2e $hex3/00" | sed "s/\///g" )
    echo $nvme1hex

    nvme3hex=$(echo "$hex1$hex2 2e$hex3")
    echo $nvme3hex
fi

echo ""
echo "Collecting 2nd nvme paths"
nvmepath2=$(readlink /sys/class/nvme/nvme1 | sed 's|^.*\(pci.*\)|\1|' | cut -d'/' -f2- | cut -d'/' -f1)
echo "Found local 2nd nvme with path $nvmepath2"
if [ $(echo $nvmepath2 | wc -w) -eq 0 ]; then
    echo "Not found local 2nd nvme"
else
    hex4=$(readlink /sys/class/nvme/nvme1 | sed 's|^.*\(pci.*\)|\1|' | cut -d'/' -f2- | cut -d'/' -f1 | awk -F ":" '{print $3}' | cut -c 1-1 | xxd  -c 256 -ps | sed "s/..$//")
    hex5=$(readlink /sys/class/nvme/nvme1 | sed 's|^.*\(pci.*\)|\1|' | cut -d'/' -f2- | cut -d'/' -f1 | awk -F ":" '{print $3}' | cut -c 2-2 | xxd  -c 256 -ps | sed "s/..$//")
    hex6=$(readlink /sys/class/nvme/nvme1 | sed 's|^.*\(pci.*\)|\1|' | cut -d'/' -f2- | cut -d'/' -f1 | awk -F ":" '{print $3}' | cut -c 4-4 | xxd  -c 256 -ps | sed "s/..$//")
    nvme2hex=$(echo "$hex4$hex5 2e$hex6")
    echo $nvme2hex

    nvme4hex=$(echo "3a$hex4 $hex5/2e $hex6/00" | sed "s/\///g" )
    echo $nvme4hex
fi

if [ $(uname -a | grep '918+\|1019+\|1621xs+' | wc -l) -gt 0 ]; then
    echo "Backup & Copy original libsynonvme.so.1 file to root home"
    if [ -f /lib64/libsynonvme.so.1.bak ]; then
        echo "Found libsynonvme.so.1.bak file"
    else
        cp /lib64/libsynonvme.so.1 /lib64/libsynonvme.so.1.bak
    fi    
    cp /lib64/libsynonvme.so.1.bak /root/libsynonvme.so
fi

if [ $(uname -a | grep '918+' | wc -l) -gt 0 ]; then
    if [ $(echo $nvmepath2 | wc -w) -gt 0 ]; then
        xxd -c 256 /root/libsynonvme.so | sed "s/3a31 332e 3100/$nvme1hex/" | sed "s/3133 2e32/$nvme2hex/" | xxd -c 256 -r > /lib64/libsynonvme.so.1
    else
        xxd -c 256 /root/libsynonvme.so | sed "s/3a31 332e 3100/$nvme1hex/" | xxd -c 256 -r > /lib64/libsynonvme.so.1
    fi
elif [ $(uname -a | grep '1019+' | wc -l) -gt 0 ]; then
    xxd /root/libsynonvme.so | sed "s/3134 2e31/$nvme3hex/" | xxd -r > /lib64/libsynonvme.so.1
elif [ $(uname -a | grep '1621xs+' | wc -l) -gt 0 ]; then
    if [ $(echo $nvmepath2 | wc -w) -gt 0 ]; then
        xxd -c 256 /root/libsynonvme.so | sed "s/3031 2e31/$nvme3hex/" | sed "s/3a30 312e 3000/$nvme4hex/" | xxd -c 256 -r > /lib64/libsynonvme.so.1
    else
        xxd -c 256 /root/libsynonvme.so | sed "s/3031 2e31/$nvme3hex/" | xxd -c 256 -r > /lib64/libsynonvme.so.1
    fi
else
    if [ $(echo $nvmepath1 | wc -w) -gt 0 ]; then
        if [ -f /etc/extensionPorts ]; then
            sed -i "/pci1=\"*\"/cpci1=\"$nvmepath1\"" /etc/extensionPorts
        else
            echo "pci1=\"$nvmepath1\"" > /etc/extensionPorts
        fi
        cat /etc/extensionPorts
        if [ -f /etc.defaults/extensionPorts ]; then
            sed -i "/pci1=\"*\"/cpci1=\"$nvmepath1\"" /etc.defaults/extensionPorts
        else
            cp -vf /etc/extensionPorts /etc.defaults/extensionPorts
        fi
        cat /etc.defaults/extensionPorts
    fi

    if [ $(echo $nvmepath2 | wc -w) -gt 0 ]; then
        if [ -f /etc/extensionPorts ]; then
            sed -i '3d' /etc/extensionPorts
            echo "pci2=\"$nvmepath2\"" >> /etc/extensionPorts
            cat /etc/extensionPorts
        fi
        if [ -f /etc.defaults/extensionPorts ]; then
            sed -i '3d' /etc.defaults/extensionPorts
            echo "pci2=\"$nvmepath2\"" >> /etc.defaults/extensionPorts
        else
            cp -vf /etc/extensionPorts /etc.defaults/extensionPorts
        fi
        cat /etc.defaults/extensionPorts
    fi
fi

# add supportnvme="yes" , support_m2_pool="yes" to /etc.defaults/synoinfo.conf 2023.02.10
if [ -f /etc/synoinfo.conf ]; then

    echo 'add supportnvme="yes" to /etc/synoinfo.conf'
    /usr/syno/bin/synosetkeyvalue /etc/synoinfo.conf supportnvme yes
    cat /etc/synoinfo.conf | grep supportnvme
    
    echo 'add support_m2_pool="yes" to /etc/synoinfo.conf'
    /usr/syno/bin/synosetkeyvalue /etc/synoinfo.conf support_m2_pool yes
    cat /etc/synoinfo.conf | grep support_m2_pool

fi
if [ -f /etc.defaults/synoinfo.conf ]; then

    echo 'add supportnvme="yes" to /etc.defaults/synoinfo.conf'
    /usr/syno/bin/synosetkeyvalue /etc.defaults/synoinfo.conf supportnvme yes
    cat /etc.defaults/synoinfo.conf | grep supportnvme

    echo 'add support_m2_pool="yes" to /etc.defaults/synoinfo.conf'
    /usr/syno/bin/synosetkeyvalue /etc.defaults/synoinfo.conf support_m2_pool yes
    cat /etc.defaults/synoinfo.conf | grep support_m2_pool

fi

#DS918+�nvme_model_spec_get.c�%s:%d Bad paramter�0000:00:13.1�0000:00:13.2�RS1619xs+�0000:00:03.2�0000:00:03.3�DS419+�DS1019+�0000:00:14.1�DS719+�DS1621xs+�0000:00:1d.0�0000:00:01.0�04.0�05.0�08.0
#DS918+ DS1019+ DS1621xs+
#xxd /lib64/libsynonvme.so.1 |grep '3a31 332e 3100'
#xxd /lib64/libsynonvme.so.1 |grep '3a31 642e 3000'

