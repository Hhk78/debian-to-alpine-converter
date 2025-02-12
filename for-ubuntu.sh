if [ "$(whoami)" != "root" ]
then
  echo "You have to run this script as Superuser!"
  exit 1
fi
# create rootfs directory
rm -rf /etc/resolv.conf
echo nameserver 1.1.1.1 > /etc/resolv.conf
chattr +i /etc/resolv.conf
export PATH=$PATH:/sbin:/usr/sbin
swapoff -a
rm -rf /swap.img
set -ex
mkdir /rootfs
cd /rootfs
# download rootfs
repo="https://dl-cdn.alpinelinux.org/alpine/edge/releases/$(uname -m)/"
archive=$(wget -O - $repo | grep "minirootfs" | grep "tar.gz<" | sort -V | tail -n1  | cut -f 2 -d "\"")
wget -O alpine-rootfs.tar.gz $repo/$archive
# extract rootfs
tar -xf alpine-rootfs.tar.gz
rm -f alpine-rootfs.tar.gz
busybox="/rootfs/lib/ld-musl-x86_64.so.1 /rootfs/bin/busybox"
# dns fix
cp -prf /etc/resolv.conf /rootfs/etc/resolv.conf
cp -prf /etc/hosts /rootfs/etc/hosts
# install packages
chroot /rootfs apk update
chroot /rootfs apk add grub-efi grub-bios linux-edge openssh bash eudev dbus openrc
# backup current rootfs and move alpine
mkdir /debian
for dir in $(ls / | grep -v rootfs| grep -v debian | grep -v dev| grep -v sys| grep -v proc| grep -v run| grep -v tmp| grep -v home) ; do
    $busybox mv /$dir /debian/$dir
    $busybox mkdir -p /rootfs/$dir
    $busybox cp -prf /rootfs/$dir /
done
# restore fstab
$busybox cp -prf /debian/etc/fstab /etc/fstab
# restore kernel
$busybox mkdir -p /lib/modules/ /lib/firmware
$busybox cp -prf /debian/boot/* /boot/
$busybox cp -prf /debian/lib/modules/* /lib/modules/
$busybox cp -prf /debian/lib/firmware/* /lib/firmware/ || true
depmod -a
# restore root password
$busybox sed -i "/^root:.*/d" /etc/shadow
$busybox grep -e "^root:.*" /debian/etc/shadow >> /etc/shadow
# restore users
$busybox cat /debian/etc/passwd | $busybox grep "1[0-9][0-9][0-9]" | while read line ; do
    user=$(echo $line | cut -f1 -d":")
    echo $line >> /etc/passwd
    $busybox cat /debian/etc/shadow | $busybox grep "^$user:" >> /etc/shadow
done
# enable services

# suid fix
$busybox chmod u+s /bin/su
# erase motd file
> /etc/motd
# restore grub config
echo 'GRUB_CMDLINE_LINUX="rootfstype=ext4 modules=ext4,sd-mod,network quiet"' >> /etc/default/grub
$busybox cp -prf /debian/boot/grub /boot/grub
grub-mkconfig -o /boot/grub/grub.cfg
sync

/rootfs/bin/cat /debian/etc/network/interfaces > /etc/network/interfaces || true
#$busybox cp -prf /etc/network/interfaces /rootfs/etc/network/interfaces
rc-update add networking boot
rc-update add networking 
rc-update add networking default
rc-update add udev default
rc-update add udev
rc-update add udev boot
rc-update add dbus boot
rc-update add dbus default
rc-update add dbus
rc-update add sshd boot
rc-update add sshd default
rc-update add sshd 
/rootfs/bin/sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
echo "root:31" | chpasswd
passwd root
#echo 'GRUB_CMDLINE_LINUX="rootfstype=ext4 modules=ext4,sd-mod,network quiet"' >> /etc/default/grub
echo 'features="ata base cdrom ext4 keymap kms mmc nvme raid scsi usb virtio eudev"' > /etc/mkinitfs/mkinitfs.conf
#sed -i '/^start_pre() {/,/^}/ s/^}/    \/sbin\/udevd \&\n    udevadm trigger -c add\n}/' /etc/init.d/udev
cat << 'EOF' > /etc/init.d/31
#!/sbin/openrc-run

description="Custom udev startup script"

depend() {
    after localmount
}

start() {
    ebegin "Starting custom udev service"
    /sbin/udevd &
    udevadm trigger -c add
    eend $?
}
EOF

chmod +x /etc/init.d/31
rc-update add 31 default
rc-update add 31 boot
rc-update add 31 sysinit
#!/bin/bash

# /etc/network/interfaces dosyasının başını oluştur
echo "# Auto-generated interfaces file based on 'ip addr show' and 'ip route' commands" > /etc/network/interfaces
echo "" >> /etc/network/interfaces

# Varsayılan gateway'i bul
default_gateway=$(ip route show default | awk '/default/ {print $3}')
if [ -z "$default_gateway" ]; then
    echo "No default gateway found!"
    exit 1
fi

echo "Default gateway found: $default_gateway"
echo "" >> /etc/network/interfaces

# Varsayılan ağ arayüzünü bul
default_iface=$(ip route show default | awk '/default/ {print $5}')
if [ -z "$default_iface" ]; then
    echo "No default interface found!"
    exit 1
fi

# ip addr show komutundan varsayılan ağ arayüzünün IP adresini almak
ip_addr=$(ip -o -4 addr show dev $default_iface | awk '{print $4}')
if [ -z "$ip_addr" ]; then
    echo "No IP address found for $default_iface!"
    exit 1
fi

# IP adresini ve ağ maskesini çıkar
netmask=$(echo $ip_addr | cut -d'/' -f2)
ip=$(echo $ip_addr | cut -d'/' -f1)

# interfaces dosyasına yaz
echo "auto eth0" >> /etc/network/interfaces
echo "iface eth0 inet static" >> /etc/network/interfaces
echo "    address $ip" >> /etc/network/interfaces
echo "    netmask 255.255.255.0" >> /etc/network/interfaces
echo "    gateway $default_gateway" >> /etc/network/interfaces
echo "" >> /etc/network/interfaces

echo "Interfaces file has been generated at /etc/network/interfaces"

cat << 'EOF' > /etc/init.d/3131
#!/sbin/openrc-run

description="Custom udev startup script"

depend() {
    after localmount
}

start() {
    ebegin "Starting custom udev service"
    sleep 5 && rc-service networking restart
    eend $?
}
EOF

chmod +x /etc/init.d/3131
rc-update add 3131 default
rc-update add 3131 boot
rc-update add 3131 sysinit


echo "bitti. reboot -f atmadan önce yedek aldığınızdan emin olun."
# reboot -f
