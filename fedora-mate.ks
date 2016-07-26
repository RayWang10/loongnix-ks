# Desktop with customizations to fit in a CD (package removals, etc.)
# Maintained by the Fedora Desktop SIG:
# http://fedoraproject.org/wiki/SIGs/Desktop
# mailto:desktop@lists.fedoraproject.org

lang zh_CN.UTF-8
keyboard us
timezone Asia/Shanghai
auth --useshadow --enablemd5
selinux --enforcing
firewall --enabled --service=mdns
xconfig --startxonboot
part / --size 8192 --fstype ext3
services --enabled=NetworkManager --disabled=network
repo --name=fedora --baseurl=http://ftp.loongnix.org/os/loongnix/1.0/os/

%packages
######################
# Install
######################
@base-x
@guest-desktop-agents
@standard
@core
@fedora-release-nonproduct
@fonts
@input-methods
@dial-up
@multimedia
@hardware-support
@printing
@mate-desktop
@networkmanager-submodules
#@libreoffice
@anaconda-tools
# Some development tools
@c-development
# web browser
@firefox
@eclipse
@java
@system-tools

# some apps from mate-applications
@mate-applications

# for logos
#generic-logos
#generic-logos-httpd

# Explicitly specified here:
# <notting> walters: because otherwise dependency loops cause yum issues.
kernel

# The point of a live image is to install
usermode
anaconda

# Need aajohan-comfortaa-fonts for the SVG rnotes images
aajohan-comfortaa-fonts

# FIXME; apparently the glibc maintainers dislike this, but it got put into the
# desktop image at some point.  We won't touch this one for now.
nss-mdns

# audio and video player
smplayer

# for flashplayer sound
alsa-lib.mipsel

# chrome
chrome39

# chinese support
adobe-source-han-sans-cn-fonts
ibus-table-chinese-wubi-jidian
#libreoffice-langpack-en
#libreoffice-langpack-zh-Hans
wqy-microhei-fonts
eclipse-nls-zh

# printer driver
foo2*

# mozilla openh264 plugin
mozilla-openh264

# other packages
hunspell-en
hunspell-en-GB
hunspell-en-US
pptp-setup
remmina
remmina-plugins-rdp
NetworkManager-wifi
NetworkManager-pptp-gnome

######################
# Remove
######################
-sox
-autofs

# scanning takes quite a bit of space :/
-xsane
-xsane-gimp
-sane-backends
-PackageKit*                # we switched to yumex, so we don't need this
-ConsoleKit                 # ConsoleKit is deprecated
-ConsoleKit-x11             # ConsoleKit is deprecated
# First, no office
-planner

# Drop things for size
-@libreoffice
-@3d-printing
-brasero
-fedora-icon-theme
-gnome-bluetooth-libs
-gnome-software
-gnome-themes
-gnome-user-docs
-atril-thumbnailer
-transmission-gtk
-bluedevil
-hexchat
-pidgin
-tigervnc
-gnote
-caja-actions
-caja-terminal
-*beesu-*
-firewall-*

# Drop the Java plugin
-icedtea-web

# Drop things that pull in perl
-linux-atm

# Dictionaries are big
# we're going to try keeping hunspell-* after notting, davidz, and ajax voiced
# strong preference to giving it a go on #fedora-desktop.
# also see http://bugzilla.gnome.org/681084
-aspell-*

# Help and art can be big, too
-gnome-user-docs
-evolution-help
-desktop-backgrounds-basic
-*backgrounds-extras

# Legacy cmdline things we don't want
-krb5-auth-dialog
-krb5-workstation

-ypbind
-yp-tools

# Drop some system-config things
-system-config-rootpassword
-system-config-services
-policycoreutils-gui

%end

%post
# FIXME: it'd be better to get this installed from a package
cat > /etc/rc.d/init.d/livesys << EOF
#!/bin/bash
#
# live: Init script for live image
#
# chkconfig: 345 00 99
# description: Init script for live image.
### BEGIN INIT INFO
# X-Start-Before: display-manager
### END INIT INFO

. /etc/init.d/functions

if ! strstr "\`cat /proc/cmdline\`" rd.live.image || [ "\$1" != "start" ]; then
    exit 0
fi

if [ -e /.liveimg-configured ] ; then
    configdone=1
fi

exists() {
    which \$1 >/dev/null 2>&1 || return
    \$*
}

livedir="LiveOS"
for arg in \`cat /proc/cmdline\` ; do
  if [ "\${arg##rd.live.dir=}" != "\${arg}" ]; then
    livedir=\${arg##rd.live.dir=}
    return
  fi
  if [ "\${arg##live_dir=}" != "\${arg}" ]; then
    livedir=\${arg##live_dir=}
    return
  fi
done

# enable swaps unless requested otherwise
swaps=\`blkid -t TYPE=swap -o device\`
if ! strstr "\`cat /proc/cmdline\`" noswap && [ -n "\$swaps" ] ; then
  for s in \$swaps ; do
    action "Enabling swap partition \$s" swapon \$s
  done
fi
if ! strstr "\`cat /proc/cmdline\`" noswap && [ -f /run/initramfs/live/\${livedir}/swap.img ] ; then
  action "Enabling swap file" swapon /run/initramfs/live/\${livedir}/swap.img
fi

mountPersistentHome() {
  # support label/uuid
  if [ "\${homedev##LABEL=}" != "\${homedev}" -o "\${homedev##UUID=}" != "\${homedev}" ]; then
    homedev=\`/sbin/blkid -o device -t "\$homedev"\`
  fi

  # if we're given a file rather than a blockdev, loopback it
  if [ "\${homedev##mtd}" != "\${homedev}" ]; then
    # mtd devs don't have a block device but get magic-mounted with -t jffs2
    mountopts="-t jffs2"
  elif [ ! -b "\$homedev" ]; then
    loopdev=\`losetup -f\`
    if [ "\${homedev##/run/initramfs/live}" != "\${homedev}" ]; then
      action "Remounting live store r/w" mount -o remount,rw /run/initramfs/live
    fi
    losetup \$loopdev \$homedev
    homedev=\$loopdev
  fi

  # if it's encrypted, we need to unlock it
  if [ "\$(/sbin/blkid -s TYPE -o value \$homedev 2>/dev/null)" = "crypto_LUKS" ]; then
    echo
    echo "Setting up encrypted /home device"
    plymouth ask-for-password --command="cryptsetup luksOpen \$homedev EncHome"
    homedev=/dev/mapper/EncHome
  fi

  # and finally do the mount
  mount \$mountopts \$homedev /home
  # if we have /home under what's passed for persistent home, then
  # we should make that the real /home.  useful for mtd device on olpc
  if [ -d /home/home ]; then mount --bind /home/home /home ; fi
  [ -x /sbin/restorecon ] && /sbin/restorecon /home
  if [ -d /home/liveuser ]; then USERADDARGS="-M" ; fi
}

findPersistentHome() {
  for arg in \`cat /proc/cmdline\` ; do
    if [ "\${arg##persistenthome=}" != "\${arg}" ]; then
      homedev=\${arg##persistenthome=}
      return
    fi
  done
}

if strstr "\`cat /proc/cmdline\`" persistenthome= ; then
  findPersistentHome
elif [ -e /run/initramfs/live/\${livedir}/home.img ]; then
  homedev=/run/initramfs/live/\${livedir}/home.img
fi

# if we have a persistent /home, then we want to go ahead and mount it
if ! strstr "\`cat /proc/cmdline\`" nopersistenthome && [ -n "\$homedev" ] ; then
  action "Mounting persistent /home" mountPersistentHome
fi

if [ -n "\$configdone" ]; then
  exit 0
fi

# add fedora user with no passwd
action "Adding live user" useradd \$USERADDARGS -c "Live System User" liveuser
passwd -d liveuser > /dev/null
usermod -aG wheel liveuser > /dev/null

# Remove root password lock
passwd -d root > /dev/null

# turn off firstboot for livecd boots
systemctl --no-reload disable firstboot-text.service 2> /dev/null || :
systemctl --no-reload disable firstboot-graphical.service 2> /dev/null || :
systemctl stop firstboot-text.service 2> /dev/null || :
systemctl stop firstboot-graphical.service 2> /dev/null || :

# don't use prelink on a running live image
sed -i 's/PRELINKING=yes/PRELINKING=no/' /etc/sysconfig/prelink &>/dev/null || :

# turn off mdmonitor by default
systemctl --no-reload disable mdmonitor.service 2> /dev/null || :
systemctl --no-reload disable mdmonitor-takeover.service 2> /dev/null || :
systemctl stop mdmonitor.service 2> /dev/null || :
systemctl stop mdmonitor-takeover.service 2> /dev/null || :

# don't enable the gnome-settings-daemon packagekit plugin
gsettings set org.gnome.software download-updates 'false' || :

# don't start cron/at as they tend to spawn things which are
# disk intensive that are painful on a live image
systemctl --no-reload disable crond.service 2> /dev/null || :
systemctl --no-reload disable atd.service 2> /dev/null || :
systemctl stop crond.service 2> /dev/null || :
systemctl stop atd.service 2> /dev/null || :

# Mark things as configured
touch /.liveimg-configured

# add static hostname to work around xauth bug
# https://bugzilla.redhat.com/show_bug.cgi?id=679486
echo "localhost" > /etc/hostname

EOF

# bah, hal starts way too late
cat > /etc/rc.d/init.d/livesys-late << EOF
#!/bin/bash
#
# live: Late init script for live image
#
# chkconfig: 345 99 01
# description: Late init script for live image.

. /etc/init.d/functions

if ! strstr "\`cat /proc/cmdline\`" rd.live.image || [ "\$1" != "start" ] || [ -e /.liveimg-late-configured ] ; then
    exit 0
fi

exists() {
    which \$1 >/dev/null 2>&1 || return
    \$*
}

touch /.liveimg-late-configured

# read some variables out of /proc/cmdline
for o in \`cat /proc/cmdline\` ; do
    case \$o in
    ks=*)
        ks="--kickstart=\${o#ks=}"
        ;;
    xdriver=*)
        xdriver="\${o#xdriver=}"
        ;;
    esac
done

# if liveinst or textinst is given, start anaconda
if strstr "\`cat /proc/cmdline\`" liveinst ; then
   plymouth --quit
   /usr/sbin/liveinst \$ks
fi
if strstr "\`cat /proc/cmdline\`" textinst ; then
   plymouth --quit
   /usr/sbin/liveinst --text \$ks
fi

# configure X, allowing user to override xdriver
if [ -n "\$xdriver" ]; then
   cat > /etc/X11/xorg.conf.d/00-xdriver.conf <<FOE
Section "Device"
	Identifier	"Videocard0"
	Driver	"\$xdriver"
EndSection
FOE
fi

EOF

chmod 755 /etc/rc.d/init.d/livesys
/sbin/restorecon /etc/rc.d/init.d/livesys
/sbin/chkconfig --add livesys

chmod 755 /etc/rc.d/init.d/livesys-late
/sbin/restorecon /etc/rc.d/init.d/livesys-late
/sbin/chkconfig --add livesys-late

# enable tmpfs for /tmp
systemctl enable tmp.mount

# make it so that we don't do writing to the overlay for things which
# are just tmpdirs/caches
# note https://bugzilla.redhat.com/show_bug.cgi?id=1135475
cat >> /etc/fstab << EOF
vartmp   /var/tmp    tmpfs   defaults   0  0
varcacheyum /var/cache/yum  tmpfs   mode=0755,context=system_u:object_r:rpm_var_cache_t:s0   0   0
EOF

# work around for poor key import UI in PackageKit
rm -f /var/lib/rpm/__db*
releasever=$(rpm -q --qf '%{version}\n' --whatprovides system-release)
basearch=$(uname -i)
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-$releasever-$basearch
echo "Packages within this LiveCD"
rpm -qa
# Note that running rpm recreates the rpm db files which aren't needed or wanted
rm -f /var/lib/rpm/__db*

# go ahead and pre-make the man -k cache (#455968)
/usr/bin/mandb

# save a little bit of space at least...
rm -f /boot/initramfs*
# make sure there aren't core files lying around
rm -f /core*

# convince readahead not to collect
# FIXME: for systemd

# forcibly regenerate fontconfig cache (so long as this live image has
# fontconfig) - see #1169979
if [ -x /usr/bin/fc-cache ] ; then
   fc-cache -f
fi

# This is a huge file and things work ok without it
rm -f /usr/share/icons/HighContrast/icon-theme.cache

cat >> /etc/rc.d/init.d/livesys << EOF


# make the installer show up
if [ -f /usr/share/applications/liveinst.desktop ]; then
  # Show harddisk install in shell dash
  sed -i -e 's/NoDisplay=true/NoDisplay=false/' /usr/share/applications/liveinst.desktop ""
  sed -i -e 's/NoDisplay=true/NoDisplay=false/' /usr/share/applications/netinst.desktop ""
fi
mkdir /home/liveuser/Desktop
cp /usr/share/applications/liveinst.desktop /home/liveuser/Desktop
cp /usr/share/applications/netinst.desktop /home/liveuser/Desktop

# rebuild schema cache with any overrides we installed
glib-compile-schemas /usr/share/glib-2.0/schemas

# set up lightdm autologin
sed -i 's/^#autologin-user=.*/autologin-user=liveuser/' /etc/lightdm/lightdm.conf
sed -i 's/^#autologin-user-timeout=.*/autologin-user-timeout=0/' /etc/lightdm/lightdm.conf
#sed -i 's/^#show-language-selector=.*/show-language-selector=true/' /etc/lightdm/lightdm-gtk-greeter.conf

# set MATE as default session, otherwise login will fail
sed -i 's/^#user-session=.*/user-session=mate/' /etc/lightdm/lightdm.conf

# Turn off PackageKit-command-not-found while uninstalled
if [ -f /etc/PackageKit/CommandNotFound.conf ]; then
  sed -i -e 's/^SoftwareSourceSearch=true/SoftwareSourceSearch=false/' /etc/PackageKit/CommandNotFound.conf
fi

# make sure to set the right permissions and selinux contexts
chown -R liveuser:liveuser /home/liveuser/
restorecon -R /home/liveuser/
EOF
%end


%post --nochroot
# product info
cat > $INSTALL_ROOT/.buildstamp << EOF
[Main]
Product=Fedora
Version=21
BugURL=your distribution provided bug reporting tool
IsFinal=True
UUID=201607261352.mips64
[Compose]
Lorax=19.6.28-1
EOF

# for java plugin
ln -sf /usr/lib/jvm/java/jre/lib/mips64el/libnpjp2.so $INSTALL_ROOT/usr/lib64/mozilla/plugins/libnpjp2.so

# install scripts
cat > $INSTALL_ROOT/usr/sbin/system-installer << EOF
#!/bin/bash

ANACONDA="/usr/sbin/anaconda"
ANACONDA_CLEANUP="/usr/bin/anaconda-cleanup"
ARGS="-G --noreboot"

if [ "--liveinst" == "\${1}" ]; then
        ARGS="\${ARGS} --liveinst --method livecd:/dev/mapper/live-osimg-min"
fi

# disable screen saver blanking
killall mate-screensaver > /dev/null 2>&1
xset s off > /dev/null 2>&1
xset -dpms > /dev/null 2>&1

sudo \${ANACONDA} \${ARGS}
sudo \${ANACONDA_CLEANUP} \${1}

# enable screen saver blanking
xset s on > /dev/null 2>&1
xset +dpms > /dev/null 2>&1
EOF
chmod +x $INSTALL_ROOT/usr/sbin/system-installer

cat > $INSTALL_ROOT/usr/share/applications/liveinst.desktop << EOF
#!/usr/bin/env xdg-open
[Desktop Entry]
NoDisplay=true
Name=Install System
Name[en_AU]=Install System
Name[en_GB]=Install System
Name[zh_CN]=安装系统
Name[zh_TW]=安裝系統
Exec=/usr/sbin/system-installer --liveinst
Icon=stock_xfburn-import-session
Terminal=false
Type=Application
StartupNotify=true
EOF

cat > $INSTALL_ROOT/usr/share/applications/netinst.desktop << EOF
#!/usr/bin/env xdg-open
[Desktop Entry]
NoDisplay=true
Name=Install System from Network
Name[en_AU]=Install System from Network
Name[en_GB]=Install System from Network
Name[zh_CN]=网络安装系统
Name[zh_TW]=網絡安裝系統
Exec=/usr/sbin/system-installer
Icon=anaconda
Terminal=false
Type=Application
StartupNotify=true
EOF

# install adobe flash config file
tar xf adobe.tar.gz -C $INSTALL_ROOT/etc/

# remove youtube player
rm -f $INSTALL_ROOT/usr/share/applications/smtube.desktop

%end
