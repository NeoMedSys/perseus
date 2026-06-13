{ pkgs, ... }:
{
  services.hardware.bolt.enable = true;
  boot.initrd.availableKernelModules = [
    "usbhid"
    "hid_generic"
    "hid_multitouch"
    "xhci_pci"
    "hid_logitech_dj"
    "thunderbolt"
  ];
}
