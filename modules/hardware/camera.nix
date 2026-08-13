{ ... }:
{
  nixpkgs.overlays = [
    (final: prev: {
      libcamera = prev.libcamera.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          ../../patches/libcamera-ov02c10-sensor-helper.patch
        ];
      });
    })
  ];
}
