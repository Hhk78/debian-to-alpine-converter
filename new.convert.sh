# create rootfs directory
export PATH=$PATH:/sbin:/usr/sbin
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

/rootfs/bin/cat /debian/etc/network/interfaces > /etc/network/interfaces
$busybox cp -prf /etc/network/interfaces /rootfs/etc/network/interfaces
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
ip a
ifconfig
# Ağ kartı ismini sor
read -p "Ağ kartı ismini girin (örnek: eth0): " network_interface

# /etc/network/interfaces dosyasındaki 'ens192' kısmını değiştir ve 'lo' satırlarını sil
sed "s/$network_interface/eth0/g" /debian/etc/network/interfaces | sed '/lo/d'  | sed '/source/d' > 31
echo auto $network_interface >> 31
echo auto eth0 >> 31
$busybox cat 31 >> /etc/network/interfaces
$busybox sed '/source/d' -i /etc/network/interfaces
$busybox rm -rf 31
echo "bitti. reboot -f atmadan önce yedek aldığınızdan emin olun."
# reboot -f
