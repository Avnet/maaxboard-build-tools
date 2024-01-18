# 1 Introduction

This project is a build system for MaaXBoard BSP(Board Support Package) developer, it will auto download all the source code and build for it. It also can generate a linux system image, which can be flash into eMMC or TF card and boot up from it.

The build system can support:

* [MaaXBoard](https://www.avnet.com/wps/portal/us/products/avnet-boards/avnet-board-families/maaxboard/maaxboard)
* [MaaXBoard Mini](https://www.avnet.com/wps/portal/us/products/avnet-boards/avnet-board-families/maaxboard/maaxboard-mini)
* [MaaXBoard 8ULP](https://www.avnet.com/wps/portal/us/products/avnet-boards/avnet-board-families/maaxboard/maaxboard-8ulp/)
* [MaaXBoard Nano](https://www.avnet.com/wps/portal/us/products/avnet-boards/avnet-board-families/maaxboard/maaxboard-nano)
* MaaXBoard OSM93



And it test on ***Ubuntu-20.04***.

```
guowenxue@7eeebdd3d42f:~$ lsb_release -a
No LSB modules are available.
Distributor ID: Ubuntu
Description:    Ubuntu 20.04.4 LTS
Release:        20.04
Codename:       focal
```



Take **MaaXBoard 8ULP** for example, You can create the work space and fetch the build system tools.

```
guowenxue@7eeebdd3d42f:~$ git clone https://github.com/Avnet/maaxboard-build-tools.git maaxboard-8ulp

guowenxue@7eeebdd3d42f:~$ cd maaxboard-8ulp && ls
bootloader  config.json  images  kernel  tools  yocto
```



Below is the build system files.

| File                     | Description                                              |
| ------------------------ | -------------------------------------------------------- |
| **config.json**          | The build system configure file                          |
| **bootloader/build.sh**  | The bootloader build shell script                        |
| **kernel/build.sh**      | The Linux kernel build shell script                      |
| **yocto/build.sh**       | The Yocto build shell script                             |
| **images/build.sh**      | The system image generate shell script                   |
| **tools/setup_tools.sh** | The build system setup shell script                      |
| **tools/imgmnt**         | A shell script used to mount the system image for update |



# 2 Setup



Run ***tools/setup_tools.sh*** script as ***root*** to install all the dependent system tools and cross compiler for this build system.

```
guowenxue@7eeebdd3d42f:~/maaxboard-8ulp$ sudo ./tools/setup_tools.sh

 --I-- start apt install system tools(commands)

 --I-- start apt install devlopment tools(commands)

 --I-- start download cross compiler from ARM Developer for Cortex-M core
 --I-- cross compiler for Cortex-M installed to "/opt/gcc-arm-none-eabi-10.3-2021.07" successfully

 --I-- start download cross compiler from ARM Developer for Cortex-A core
 --I-- cross compiler for Cortex-A installed to "/opt/gcc-arm-10.3-2021.07" successfully
```



***NOTE:  MaaXBoard-8ULP need build the Cortex-M core SDK, so need install cross compiler for it.***



# 3 Configure



***config.json*** is the default configure file for the build system.

```
guowenxue@7eeebdd3d42f:~/maaxboard-8ulp$ cat config.json
{
    "bsp":
    {
        "board":"maaxboard",
        "version":"lf-6.1.22-2.0.0",
        "giturl":"https://github.com/Avnet/",
        "cortexAtool":"/opt/gcc-arm-10.3-2021.07/bin/aarch64-none-linux-gnu-",
        "cortexMtool":"/opt/gcc-arm-none-eabi-10.3-2021.07/"
    },
    "system":
    {
        "distro":"yocto",
        "version":"mickledore",
        "imgsize":"5120",
        "bootsize":"100"
    }
}
```



***BSP(Board Support Package)*** configure options:

* **board**      Set the MaaXBoard board name here, it should be ***maaxboard, maaxboard-mini, maaxboard-8ulp, maaxboard-osm93 or maaxboard-nano***;
* **version**   Set the BSP version, it support ***lf-6.1.22-2.0.0***, ***lf-6.1.1-1.0.0*** and ***lf-5.15.71-2.2.0*** till now;
* **giturl**       MaaXBoard BSP source code git repository download URL;
* **cortexAtool**   Set the cross compiler for Cortex-A with Linux;
* **cortexMtool**   Set the cross compiler for Cortex-M with RTOS;



***System*** configure options:

* **distro**  The linux distribution, current only support **yocto**;
* **version** The linux distribution version, current support ***mickledore***, ***langdale*** and  ***kirkstone*** for Yocto;
* ***imgsize*** The generate system image size;
* ***bootsize*** The boot partition size in system image;



# 4 Build



## 4.1  Configure



Modify the board name to ***maaxboard-8ulp***.  And you can modify some other options as your requirement, such as git repository URL.

```
guowenxue@7eeebdd3d42f:~/maaxboard-8ulp$ vim config.json
{
    "bsp":
    {
        "board":"maaxboard-8ulp",
... ...
}
```



## 4.2 Build bootloader



You can run below command to start build bootloader.

```
guowenxue@7eeebdd3d42f:~/maaxboard-8ulp$ cd bootloader && ./build.sh

guowenxue@7eeebdd3d42f:~/maaxboard-8ulp/bootloader$ ls
build.sh  firmware  imx-atf  imx-mkimage  install  mcore_sdk_8ulp  uboot-imx

guowenxue@7eeebdd3d42f:~/maaxboard-8ulp/bootloader$ ls install/
u-boot-maaxboard-8ulp.imx
```

* It will auto download [imx-atf](https://github.com/Avnet/imx-atf), [imx-mkimage](https://github.com/Avnet/imx-mkimage), [uboot-imx](https://github.com/Avnet/uboot-imx) from the git repository set in the configure file;
* It will auto download firmware image files from NXP official site;
* The build output bootloader image will be installed to foler ***bootloader/install/*** ;



## 4.3 Build kernel



You can run below command to start build linux kernel.

```
guowenxue@7eeebdd3d42f:~/maaxboard-8ulp$ cd kernel && ./build.sh

guowenxue@7eeebdd3d42f:~/maaxboard-8ulp/kernel$ ls
build.sh  install  linux-imx  mwifiex

guowenxue@7eeebdd3d42f:~/maaxboard-8ulp/kernel$ ls install/
Image  lib  maaxboard-8ulp.dtb  overlays
```

* It will auto download linux kernel source code [linux-imx](https://github.com/Avnet/linux-imx) from the git repository set in the configure file;
* It will auto download extra Wireless module driver [mwifiex](https://github.com/nxp-imx/mwifiex) from NXP official site;
* The build output linux kernel image will be installed to foler ***kernel/install/*** ;



## 4.3 Build Yocto



You can run below command to start build Yocto.

```
guowenxue@7eeebdd3d42f:~/maaxboard-8ulp$ cd yocto && ./build.sh

guowenxue@7eeebdd3d42f:~/maaxboard-8ulp/yocto$ ls
build.sh  install  mickledore-lf-6.1.22-2.0.0

guowenxue@7eeebdd3d42f:~/maaxboard-8ulp/yocto$ ls install/
avnet-image-full-maaxboard-8ulp.wic.zst  rootfs.tar.zst  u-boot-maaxboard-8ulp.bin
```

* It will auto download repo and fetch Yocto source code from NXP offical site;
* It will auto download [meta-maaxboard](https://github.com/Avnet/meta-maaxboard) from the git repository set in the configure file;
* The build output Yocto system image and root file system will be installed to foler ***yocto/install/*** ;



## 4.4 Generate Image



You can run below command to start generate system image.

```
guowenxue@7eeebdd3d42f:~/maaxboard-8ulp$ cd images && sudo ./build.sh

guowenxue@7eeebdd3d42f:~/maaxboard-8ulp/images$ ls
build.sh  install  rootfs-mickledore

guowenxue@7eeebdd3d42f:~/maaxboard-8ulp/images$ ls install/
maaxboard-8ulp-mickledore.img  u-boot-maaxboard-8ulp.imx
```

* Build system image need **sudo** privilege;
* It will auto find bootloader image file in **bootloader/install**;
* It will auto find linux kernle image files in **kernel/install**;
* It will auto find root file system tarball file in **yocto/install**;
* The generate output system image will installed to foler ***images/install*** ;



## 4.5 Update Image



You can install the **imgmnt** tool to system path ***/usr/bin***;

```
guowenxue@7eeebdd3d42f:~/maaxboard-8ulp$ sudo cp tools/imgmnt /usr/bin/
guowenxue@7eeebdd3d42f:~/maaxboard-8ulp$ sudo chmod +x /usr/bin/imgmnt
```



We can mount the system image by **imgmnt** command with **'-m'** option.

```
guowenxue@7eeebdd3d42f:~/maaxboard-8ulp/images/install$ sudo imgmnt -m maaxboard-8ulp-mickledore.img
INFO: losetup /dev/loop0 maaxboard-8ulp-mickledore.img
INFO: kpartx -av /dev/loop0
add map loop0p1 (253:0): 0 194560 linear 7:0 20480
add map loop0p2 (253:1): 0 10270720 linear 7:0 215040
INFO: mount boot rootfs
INFO: mount maaxboard-8ulp-mickledore.img done.
```



It will mount the **boot partition(FAT32)** to ***boot*** folder and  **root file system partition(EXT4)** to ***rootfs*** folder.

```
guowenxue@7eeebdd3d42f:~/maaxboard-8ulp/images/install$ ls boot/
Image  maaxboard-8ulp.dtb  overlays  readme.txt  uEnv.txt

guowenxue@7eeebdd3d42f:~/maaxboard-8ulp/images/install$ ls rootfs/
bin  boot  dev  etc  home  lib  lost+found  media  mnt  opt  proc  run  sbin  srv  sys  tmp  unit_tests  usr  var
```



After mount the system image on the linux system, now we can:

* Update bootloader or linux kernel image files in mount point **boot**;
* Update application program files in mount point **rootfs**;



We can unmount the system image by **imgmnt** command with **'-u'** option.

```
guowenxue@7eeebdd3d42f:~/maaxboard-8ulp/images/install$ sudo imgmnt -u maaxboard-8ulp-mickledore.img
INFO: umount boot
INFO: umount rootfs
INFO: kpartx -dv /dev/loop0
del devmap : loop0p1
del devmap : loop0p2
INFO: losetup -d /dev/loop0
INFO: umount maaxboard-8ulp-mickledore.img done.
```

