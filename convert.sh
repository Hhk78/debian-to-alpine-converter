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
chroot /rootfs apk add grub-efi grub-bios openssh bash networkmanager eudev dbus openrc
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
for service in sshd networkmanager udev dbus ; do
    rc-update add $service || true
done
# suid fix
$busybox chmod u+s /bin/su
# erase motd file
> /etc/motd
# restore grub config
$busybox cp -prf /debian/boot/grub /boot/grub
grub-mkconfig -o /boot/grub/grub.cfg
sync

/rootfs/bin/cat /etc/network/interfaces > /etc/network/interfaces
rc-update add networking boot
rc-update add networking 
rc-update add networking default

rc-update add sshd boot
rc-update add sshd default
rc-update add sshd 
/rootfs/bin/sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
passwd root

# reboot -f
