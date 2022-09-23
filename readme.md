# 1. Introduction



## 1.1 Build system tools



Create the work space and fetch the MaaxBoard-8ULP build system tools.

```
guowenxue@fa5fc3c83566:~$ mkdir maaxboard-8ulp && cd maaxboard-8ulp
guowenxue@fa5fc3c83566:~/maaxboard-8ulp$ git clone -b maaxboard_lf-5.15.5-1.0.0 https://xterra2.avnet.com/embest/imx8ulp/build-tools.git
guowenxue@fa5fc3c83566:~/maaxboard-8ulp$ cd build-tools/
```



Below is the build system files.

```
guowenxue@fa5fc3c83566:~/maaxboard-8ulp/build-tools$ ls
build_image.sh  build_kernel.sh  build_rootfs.sh  build_uboot.sh
config  config.json  files  func_tools.sh  readme.md  setup_tools.sh  source.sh
```



* **build_image.sh**          This script used to generate system image file.
* **build_kernel.sh**          This script used to build linux kernel source code.
* **build_rootfs.sh**           This script used to install linux driver or some other files to root file system.
* **build_uboot.sh**           This script used to build bootloader.
* **config**                           This folder used to storage the build system configure files.
* **config.json**                  This is a symbolic link to the default configure file in ***config*** folder.
* **files**                               This folder used to storage some files need to be installed to root file system.
* **func_tools.sh**              This file include some common functions for other shell scripts.
* **setup_tools.sh**            This script used to install system tools and cross compiler for this build system.
* **source.sh**                    This script used to setup the build environment.



***Notice:***

This build system is test on ***Ubuntu-20.04***.

```
guowenxue@fa5fc3c83566:~$ lsb_release -a
No LSB modules are available.
Distributor ID: Ubuntu
Description:    Ubuntu 20.04.3 LTS
Release:        20.04
Codename:       focal
```



## 1.2. Configuration



***config.json*** is the default configure file for the build system, which is a symbolic link to the latest BSP(Board Support Package) configure file in ***config*** directory.



### 1.2.1 common

```
    "common":
    {
        "board":"maaxboard-8ulp",
        "bsp":"5.15.5-1.0.0",
        "crosstool":"aarch64-linux-gnu-"
    },
```

* **board**:    Set the board name here. It will be export as the value of environment variable ***BOARD***;
* **bsp**:        Set the BSP version here. It will be export as the value of environment variable ***BSP_VERSION***;
* **crosstool**:  Set the cross compiler. It will be export as the value of environment variable ***CROSSTOOL***;



***NOTICE:***

1. ***board*** should be ***maaxboard-8ulp*** for MaaXBoard-8ULP;
2. ***bsp*** only support ***5.15.5-1.0.0*** till now;
4. **crosstool**  ***aarch64-linux-gnu-*** will be installed by ***avnet_tools/setup_tools.sh***



### 1.2.2 system image

```
    "image":
    {
        "rootfs":"${FS_PATH}/rootfs.tar.bz2",
        "name":"linux-system-${BOARD}.img",
        "size":"4096"
    },
```

* **rootfs**:  Set the root file system tarball file path;
* **name**:   Set the linux system image name;
* **size**:      Set the linux system image size, unit in MB;



### 1.2.3 git server

```
    "git":
    {
        "server":"https://xterra2.avnet.com/embest/imx8ulp",
        "username":"myusername",
        "password":"mypassword",
        "option":"--depth=1"
    },
```

* **server**:   Set the MaaXBoard-8ULP common BSP repository server address;
* **username**:  Set the username to access the git repository if necessary; 
* **password**:  Set the user's password to access the git repository if necessary;
* **option**:   Set the global options for git clone command;



***NOTICE:***

  If the ***username*** or ***password*** is not necessary for git clone the repository,  you can remove them or left them as blank.



### 1.2.4 bsp repository

```
    "linux-imx":
    {
        "name":"linux-imx.git",
        "branch":"maaxboard_lf-${BSP_VERSION}"
    },
    "uboot-imx":
    {
        "name":"uboot-imx.git",
        "branch":"maaxboard_lf-${BSP_VERSION}"
    },
    "m33-sdk":
    {
        "name":"m33-sdk.git",
        "branch":"maaxboard_lf-${BSP_VERSION}"
    },
    "imx-atf":
    {
        "url":"https://source.codeaurora.org/external/imx/imx-atf",
        "branch":"lf-${BSP_VERSION}"
    },
    "imx-mkimage":
    {
        "url":"https://source.codeaurora.org/external/imx/imx-mkimage",
        "branch":"lf-${BSP_VERSION}"
    },
    "firmware":
    {   
        "url":"https://www.nxp.com/lgfiles/NMG/MAD/YOCTO/",
        "files":"firmware-imx-8.16.bin firmware-sentinel-0.5.bin firmware-upower-0.1.3.bin imx8ulp-m33-demo-2.12.0.bin"
    }      
```



* **name**:  Set the corresponding git repository name. It will download from the common BSP repository server address set above;
* **url**:  Set the git repository URL, which can be used to download source code from another server, but not the common repository server;
* **branch**:  Set the branch name in the git repository;
* **option**:   Set the local options for this git clone command if needed;
* ***firmware***:  These files are prebuild firmware images from NXP for i.MX8ULP.



***NOTICE:***

* Linux kernel、U-boot and Cortex-M33 SDK source code will download from common BSP repository server.
* ATF、mkimage tools will download from NXP's official repository.



If you wanna download the source code from another URL, but not from the common BSP repository server. You can use **url** but not **name**:

```
    "linux-imx":
    {
        "url":"git@192.168.2.100:imx8ulp/linux-imx.git",
        "branch":"maaxboard_lf-${BSP_VERSION}"
    },
```



# 2. Build



## 2.1  Install system tools



Run **`setup_tools.sh`** script as ***root*** to install all the dependent system tools and cross compiler for this build system.

```
guowenxue@fa5fc3c83566:~/maaxboard-8ulp/build-tools$ sudo ./setup_tools.sh
```



## 2.2 Update configure file



The default configure file ***config.json*** is a symbolic link to the latest BSP default configure file.

```
guowenxue@fa5fc3c83566:~/maaxboard-8ulp/build-tools$ ls -l config.json 
lrwxrwxrwx 1 guowenxue guowenxue 29 Sep 23 16:43 config.json -> config/config-5.15.5-1.0.json
```



If you wanna use some other configure file,  then you can remove the symbolic link file and copy a new one for it.

```
guowenxue@fa5fc3c83566:~/maaxboard-8ulp/build-tools$ rm -f config.json 
guowenxue@fa5fc3c83566:~/maaxboard-8ulp/build-tools$ cp config/config-5.15.5-1.0.json config.json
```



And **please remember modify username and password** for the BSP git repository as your environment.

```
guowenxue@7eeebdd3d42f:~/maaxboard-8ulp/maaxboard-tools$ vim config.json 
    "git":
    {
        "server":"https://xterra2.avnet.com/embest/imx8ulp",
        "username":"myusername",
        "password":"mypassword",
        "option":"--depth=1"
    }
```

 

## 2.3 Setup build environment



Run **`source source.sh`** command to set up the build environment.

```
guowenxue@fa5fc3c83566:~/maaxboard-8ulp/build-tools$ source source.sh 
 
### Shell environment set up for builds. ###
 
 You can now run 'build <target>', and common targets are:
 
        bootloader: Build bootloader only. 
        kernel    : Build linux kernel only. 
        image     : Build system image only. 
        sdk       : Build all the above targets together. 

 Example for build SDK system image:
 
        1. cp /path/to/rootfs-xxx.tar.bz2 ./rootfs/rootfs.tar.bz2 
        2. build sdk
 
/home/guowenxue/maaxboard-8ulp/build
bootloader  images  kernel  rootfs  tmp

```



It will create a new working folder named ***build***, which is in the same folder as ***maaxboard-tools***.

```
guowenxue@fa5fc3c83566:~/maaxboard-8ulp/build$ ls ..
build  build-tools

guowenxue@fa5fc3c83566:~/maaxboard-8ulp/build$ ls
bootloader  images  kernel  rootfs  tmp
```

* **bootloader**    The u-boot build task working directory, and this path will be export as the value of environment variable ***BL_PATH***;
* **kernel**            The linux kernel build task working directory, and this path will be export as the value of environment variable ***KR_PATH***;
* **rootfs**            The rootfs build task working directory, and this path will be export as the value of environment variable ***FS_PATH***;
* **tmp**                The temporary files output directory, and this path will be export as the value of environment variable ***TMP_PATH***;
* **images**          The system images output directory, and this path will be export as the value of environment variable ***IMG_PATH***;



## 2.4 Prepare rootfs tarball file



Now you need copy your prebuild rootfs tarball file to the ***rootfs*** folder,  which can be build by Yocto.

```
guowenxue@fa5fc3c83566:~/maaxboard-8ulp/build$ ls rootfs/
build.sh
guowenxue@fa5fc3c83566:~/maaxboard-8ulp/build$ cp ~/rootfs-honister.tar.bz2 rootfs/rootfs.tar.bz2 
```



Or you can modify **rootfs** value in ***config.json*** to your rootfs tarball file path, then no need do copy here.

```
    "image":
    {
        "rootfs":"~/rootfs-honister.tar.bz2",
        "name":"linux-system-${BOARD}.img",
        "size":"4096"
    }
```



## 2.3 Build for MaaXBoard-8ULP



Now, you can run follow command to build the target.

| Commands         | **Description**                                       |
| ---------------- | ----------------------------------------------------- |
| build bootloader | Build bootloader source code only                     |
| build kernel     | Build linux kernel source code only                   |
| build image      | Build root file system and generate system image only |
| sdk              | Build all the above targets                           |



Take example, below command start building bootloader、linux kerne and generate linux system image for MaaXBoard-8ULP.

```
guowenxue@fa5fc3c83566:~/maaxboard-8ulp/build$ build sdk
 Build system images need root privilege, please input password for sudo here:  
Password:  [ Press ENTER if sudo don't need password ]
Retype  :  [ Press ENTER if sudo don't need password ]

 --W-- start build bootloader 
 ... ...
```



After build finish, the bootloader and linux system image will deployed in ***images*** directory.

```
guowenxue@fa5fc3c83566:~/maaxboard-8ulp/build/images$ ls
build.sh  linux-system-maaxboard-8ulp.img  u-boot-maaxboard-8ulp.imx
```

