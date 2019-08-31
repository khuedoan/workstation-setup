#+-------------------------+
#| Configuration in chroot |
#+-------------------------+
# Essential packages
pacman --noconfirm -S $ucode networkmanager git gvim zsh

# Swap
if [ -n "$swap_size" ]; then
     fallocate -l $swap_size /swapfile
     chmod 600 /swapfile
     mkswap /swapfile
     swapon /swapfile
     echo "# swapfile" >> /etc/fstab
     echo "/swapfile none swap defaults 0 0" >> /etc/fstab
fi

# Timezone and localization
ln -sf /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime
hwclock --systohc
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen && locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
echo 'Precision' > /etc/hostname

# Network
systemctl enable NetworkManager

# Boot
if [ "$boot_loader" = "systemd-boot" ]; then
     bootctl --path=/boot install
     echo 'default arch' > /boot/loader/loader.conf
     echo 'timeout 0' >> /boot/loader/loader.conf
     echo 'editor  0' >> /boot/loader/loader.conf
     echo 'title   Arch Linux' > /boot/loader/entries/arch.conf
     echo 'linux   /vmlinuz-linux' >> /boot/loader/entries/arch.conf
     [ -n "$ucode" ] && echo 'initrd  /intel-ucode.img' >> /boot/loader/entries/arch.conf
     echo 'initrd  /initramfs-linux.img' >> /boot/loader/entries/arch.conf
     echo "options root=$root_partition rw quiet" >> /boot/loader/entries/arch.conf
elif [ "$boot_loader" = "efistub" ]; then
     [ -n "$ucode" ] && ucode_init="initrd=/$ucode.img"
     efibootmgr -d $disk -p 1 -c -L "Arch Linux" -l /vmlinuz-linux -u "$ucode_init initrd=/initramfs-linux.img root=$root_partition rw quiet" -v
fi

# Silent boot
sed -i 's/^HOOKS=(base udev/HOOKS=(base systemd/g' /etc/mkinitcpio.conf
mkinitcpio -p linux
echo "StandardOutput=null\nStandardError=journal+console" | SYSTEMD_EDITOR="tee -a" systemctl edit --full systemd-fsck-root.service

# Pacman
sed -i 's/^#Color/Color/g' /etc/pacman.conf
sed -i '/#\[multilib\],/#Include/ s/^#//g' /etc/pacman.conf
pacman -Syy

# Users
echo "Changing root password"
passwd
useradd -m -G wheel -s /bin/zsh -c "$fullname" "$username"
echo "Changing user password"
passwd "$username"
visudo

# Cleanup
rm /chroot.sh
exit
