{ config, pkgs, nixpkgs, systemname, systemserial, ... }:
let
  pxeLinuxCfg = ''
    DEFAULT menu.c32
    PROMPT 0
    TIMEOUT 100
    ONTIMEOUT nixos

    LABEL nixos
      MENU LABEL NixOS: ${systemname}
      LINUX ${systemname}/Image
      INITRD ${systemname}/initrd
      APPEND init=${config.system.build.toplevel}/init boot.shell_on_fail console=ttyS0,115200n8 console=ttyAMA0,115200n8 console=tty0 nohibernate loglevel=7
      FDTDIR dtb
  '';
in
{
  imports = [
    "${nixpkgs}/nixos/modules/installer/netboot/netboot-minimal.nix" # Netboot system - Kernel and ramdisk builds.
    ./rpiFirmware.nix # Raspberry Pi firmware - u-boot, config.txt, etc.
    ./rpiBoot.nix
  ];
  system.build.rpiTFTP = pkgs.callPackage
    ({ stdenv, fetchurl, ... }: stdenv.mkDerivation {
      name = "rpiTFTP";
      src = fetchurl {
        url = "https://mirrors.edge.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.gz";
        hash = "sha256-JQub2QlF02FZanpplD0L3F/AwJF6pWJgn40wWKLDazo=";
      };
      buildCommand = ''
        # Create the directory structure
        mkdir -p $out
        mkdir -p $out/dtb
        mkdir -p $out/${systemname}
        mkdir -p $out/pxelinux.cfg

        # Copy the boot firmware (config.txt, start.elf, etc)
        # This is what is first read by the Raspberry Pi, contains u-boot.
        cp -r ${config.system.build.rpiFirmware}/firmware/* $out/

        # Copy the kernel (dtbs, Image, lib, System.map)
        # This is the Linux kernel, which is loaded by u-boot.
        cp -r ${config.system.build.kernel}/* $out/${systemname}/

        # Make a second copy of the dtbs, because u-boot needs them in a different place
        cp -r ${config.system.build.kernel}/dtbs/* $out/dtb/

        # Copy the initrd from the boot directory.
        cp ${config.system.build.rpiBoot}/nixos/*initrd* $out/${systemname}/initrd
        mkdir -p $out/${systemname}/boot
        cp -r ${config.system.build.rpiBoot}/nixos/* $out/${systemname}/boot

        # Copy the netboot ramdisk.

        # Copy syslinux.
        tar -xzf $src
        cp -r syslinux-6.03/bios/com32/chain/chain.c32 $out/
        cp -r syslinux-6.03/bios/com32/mboot/mboot.c32 $out/
        cp -r syslinux-6.03/bios/memdisk/memdisk $out/
        cp -r syslinux-6.03/bios/com32/menu/menu.c32 $out/
        cp -r syslinux-6.03/bios/core/pxelinux.0 $out/

        # Copy the pxelinux config.
        echo "${pxeLinuxCfg}" > $out/pxelinux.cfg/${systemserial}
      '';
    }
    )
    { };
}
