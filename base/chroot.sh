#+-------------------------+
#| Configuration in chroot |
#+-------------------------+
# Essential packages
pacman --noconfirm -S $ucode networkmanager git ansible

# Swap
if [ -n "$swap_size" ]; then
     dd if=/dev/zero of=/swapfile bs=1GiB count=$swap_size status=progress
     chmod 600 /swapfile
     mkswap /swapfile
     swapon /swapfile
     echo "# swapfile" >> /etc/fstab
     echo "/swapfile none swap defaults 0 0" >> /etc/fstab
fi

# Timezone and localization
ln -sf /usr/share/zoneinfo/America/Los_Angeles /etc/localtime
hwclock --systohc
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen && locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
echo "$hostname" > /etc/hostname

# Network
systemctl enable NetworkManager

# Boot
if [ "$bootloader" = "systemd-boot" ]; then
     bootctl --path=/boot install
     echo 'default arch.conf' > /boot/loader/loader.conf
     echo 'console-mode auto' >> /boot/loader/loader.conf
     echo 'timeout 0' >> /boot/loader/loader.conf
     echo 'editor  0' >> /boot/loader/loader.conf
     echo 'title   Arch Linux' > /boot/loader/entries/arch.conf
     echo 'linux   /vmlinuz-linux' >> /boot/loader/entries/arch.conf
     [ -n "$ucode" ] && echo 'initrd  /intel-ucode.img' >> /boot/loader/entries/arch.conf
     echo 'initrd  /initramfs-linux.img' >> /boot/loader/entries/arch.conf
     echo "options rw nowatchdog quiet" >> /boot/loader/entries/arch.conf
elif [ "$bootloader" = "efistub" ]; then
     [ -n "$ucode" ] && ucode_init="initrd=/$ucode.img"
     efibootmgr -d $disk -p 1 -c -L "Arch Linux" -l /vmlinuz-linux -u "$ucode_init initrd=/initramfs-linux.img root=$root_partition rw quiet" -v
fi

# Silent boot
sed -i 's/^HOOKS=(base udev/HOOKS=(base systemd/g' /etc/mkinitcpio.conf
mkinitcpio -p linux
echo "StandardOutput=null\nStandardError=journal+console" | SYSTEMD_EDITOR="tee -a" systemctl edit --full systemd-fsck-root.service

# Pacman
sed -i 's/^#Color/Color/g;/#\[multilib\]/,/#Include/ s/^#//g' /etc/pacman.conf
pacman -Syy
vim /etc/pacman.conf

# Users
echo "ROOT PASSWORD"
passwd
useradd -m -G wheel -s /bin/zsh -c "$fullname" "$username"
echo "USER PASSWORD ($username)"
passwd "$username"

# Allow users in group wheel to use sudo
sed -i '/%wheel\sALL=(ALL)\sALL/s/^#\s//g' /etc/sudoers

# Change shell to zsh
chsh -s /bin/zsh
chsh -s /bin/zsh victor

# Manual intervention
vim /boot/loader/entries/arch.conf

# Cleanup
rm /chroot.sh

exit
