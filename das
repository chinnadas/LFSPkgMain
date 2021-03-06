#It will be assumed that your LFS partition is mounted on /mnt/LFS, using /dev/sda1 and /dev/sda2 as swap, alter as needed.
#Use sudo where necessary to create links etc.

#If compiling on raspberian you need to install some extra files like so:
sudo apt-get update
sudo apt-get install bison gawk  gcc g++ make m4 texinfo git vim -y

#Also make sure /bin/sh points to /bin/bash
sudo rm /bin/sh
sudo ln -s /bin/bash /bin/sh

sudo rm /usr/bin/awk 
sudo ln -s /usr/bin/gawk /usr/bin/awk


#Get the build scripts and helper scripts from:
#https://github.com/KeithDHedger/LFSPkgBuilds
#either via git clone or downloading the zip file and unpacking it.
#you should place the LFSPkgBuildScripts and LFSScripts folder in the root of what will be your new LFS eg /mnt/lfs/LFSPkgBuildScripts

#Set some env vars to make it easier to copy and paste these instructions.
#Folders should be pre created, change paths to suit,
LFS=/mnt/LFS
LFSVERSION=9.0
SOURCEARCHIVES=/LFSSourceArchives/$LFSVERSION
BUILTPACKAGES=/LFSBuiltPackages/$LFSVERSION
EXTFOLDER=
KERNELVERSION=5.2.8
USESYSTEMD=1

export LFS
export LFSVERSION
export SOURCEARCHIVES
export BUILTPACKAGES
export EXTFOLDER
export KERNELVERSION
export USESYSTEMD
bbb=`pwd`
cd $LFS
sudo wget wget https://ftp.gnu.org/gnu/cpio/cpio-2.13.tar.bz2

sudo git clone https://github.com/KeithDHedger/LFSPkgBuilds.git

#Own the files:
sudo chown -R $USER:$USER /mnt/LFS
sudo chown -R $USER:$USER $LFS/LFSPkgBuilds
sudo ln -sv LFSPkgBuilds/LFSPkgBuildScripts $LFS/LFSPkgBuildScripts
sudo ln -sv LFSPkgBuilds/LFSScripts $LFS/LFSScripts

sleep 2
cd LFSScripts
./LFSSetUp
./ShowSystemData

rm -rf BuildTools-SystemD

sudo git clone https://github.com/chinnadas/LFSPkgMain.git

sleep 5
cd $bbb

sudo cp BuildTools-SystemD $LFS/LFSScripts

sudo cp  system-meta.LFSBuild /mnt/LFS/LFSPkgBuildScripts/system/system-meta/system-systemd-meta.LFSBuild

sudo chmod 777 /mnt/LFS/LFSPkgBuildScripts/system/system-meta/system-systemd-meta.LFSBuild

cd $LFS/LFSScripts/

sudo chown -R $USER:$USER BuildTools-SystemD
sudo chmod 755 BuildTools-SystemD


sleep 3
echo "=================Building Tools for Systemd============"
echo "=================Stage 1======================="

./BuildTools-SystemD

sleep 5

. ./SystemData
mkdir -vp ${LFS}/${SOURCEARCHIVES}||true
mkdir -vp ${LFS}/${BUILTPACKAGES}||true
if [ "X$EXTFOLDER" != "X" ];then
	sudo mount --bind $EXTFOLDER/${BUILTPACKAGES} $LFS/${BUILTPACKAGES}
	sudo mount --bind $EXTFOLDER/${SOURCEARCHIVES} $LFS/${SOURCEARCHIVES}
fi


sudo ./BuildFileSystem-SystemD


sudo chown -R $USER:$USER $LFS/LFSPkgBuilds $LFS/LFSSourceArchives/$LFSVERSION $LFS/LFSBuiltPackages/$LFSVERSION

sudo chmod -R 755 $LFS/LFSSourceArchives/$LFSVERSION $LFS/LFSBuiltPackages/$LFSVERSION

mkdir  $LFS/LFSSourceArchives/$LFSVERSION/KERNEL
cd $LFS/LFSSourceArchives/$LFSVERSION/KERNEL
ln -sv ../SYSTEM/linux-$KERNELVERSION.tar.xz .

cd $LFS/LFSPkgBuildScripts/admin/LFSPkg
wget -c --no-check-certificate "https://github.com/KeithDHedger/LFSPkg/archive/master.zip" -O LFSPkg.zip
unzip LFSPkg.zip

cd $LFS/LFSSourceArchives/9.0/SYSTEM/
sudo wget https://www.openssl.org/source/old/1.1.1/openssl-1.1.1c.tar.gz

echo "==========Stage 1/4 completed========================"
sleep 2

echo "==========Entering into chroot stage =============="

echo "==========Stage 2==============================="
cd $LFS/LFSScripts


sudo ./Chroot system <<"EOT"
cd /LFSSourceArchives/9.0/SYSTEM/
tar -xf bison-3.4.1.tar.xz
cd bison-3.4.1
./configure --prefix=/tools
make -J1||make
make install

cd /LFSPkgBuildScripts/admin/LFSPkg
echo "I" |BOOTSTRAP=1 ./LFSPkg.LFSBuild install
echo "y" |lfspkg --setup
cd /LFSPkgBuildScripts/system/system-meta
./system-meta.LFSBuild install
cd /
wget http://anduin.linuxfromscratch.org/BLFS/gpm/gpm-1.20.7.tar.bz2 --no-check-certificate
wget http://www.linuxfromscratch.org/patches/blfs/svn/gpm-1.20.7-consolidated-1.patch --no-check-certificate
tar -xf gpm-1.20.7.tar.bz2
cd gpm-1.20.7
patch -Np1 -i ../gpm-1.20.7-consolidated-1.patch &&
./autogen.sh                                     &&
./configure --prefix=/usr --sysconfdir=/etc      &&
make

make install                                          &&

install-info --dir-file=/usr/share/info/dir           \
             /usr/share/info/gpm.info                 &&

ln -sfv libgpm.so.2.1.0 /usr/lib/libgpm.so            &&
install -v -m644 conf/gpm-root.conf /etc              &&

install -v -m755 -d /usr/share/doc/gpm-1.20.7/support &&
install -v -m644    doc/support/*                     \
                    /usr/share/doc/gpm-1.20.7/support &&
install -v -m644    doc/{FAQ,HACK_GPM,README*}        \
                    /usr/share/doc/gpm-1.20.7	   
EOT


cd /
sudo rm /tools
sudo rm -rf $LFS/tools
cd /mnt/LFS/LFSScripts/


sudo ./Chroot <<"EOT" 
cd /
wget https://ftp.gnu.org/gnu/cpio/cpio-2.13.tar.bz2
tar -xvf cpio-2.13.tar.bz2
cd cpio-2.13
./configure --prefix=/usr
make -J1||make
make install

sleep 2
echo "============kernelinstall stage please install kernel manually with scripts==================="

cd /LFSPkgBuildScripts/kernel
EOT

sleep 2
echo "============Stage 3===================="
echo "============kernel install stage======="

echo "============before kernel install stages completed  please install kernel manually with build scripts================="

cd /LFSPkgBuildScripts/kernel
sed -i 's/cp $KERNELCONFIG .config/#cp $KERNELCONFIG .config/g' kernel.LFSBuild
./kernel.LFSBuild install
./firmware.LFSBuild install
grub-install /dev/sda

echo "=====grub editing==========="

echo "==========Stage 4============"

cat > /boot/grub/grub.cfg << "EOF"
# Begin /boot/grub/grub.cfg
set default=0
set timeout=30

insmod ext2
set root=(hd0,7)

menuentry "GNU/Linux, yantra" {
	linux /boot/vmlinuz-5.2.8 root=/dev/sda7 ro
}
EOF

exit

echo "=========Stage 3/4 completed======"

sleep 2

echo ======grub editing completed"

sudo update-grub

echo "=======stage 4/4 completed===="

sudo umount $LFS
