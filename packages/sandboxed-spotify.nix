{ pkgs, ... }:
let
  spotify-sandbox = pkgs.writeShellScriptBin "spotify" ''
    ISOLATION_DIR="$HOME/.local/share/app-isolation/spotify"
    mkdir -p "$ISOLATION_DIR" "$ISOLATION_DIR-cache"
    USER_ID=$(id -u)
    XDG_RT="/run/user/$USER_ID"
    exec ${pkgs.systemd}/bin/systemd-run \
      --user --scope --collect \
      --unit=sandboxed-spotify-$(date +%s) \
      -p MemoryHigh=2G \
      -p MemoryMax=4G \
      ${pkgs.bubblewrap}/bin/bwrap \
        --unshare-all \
        --share-net \
        --die-with-parent \
        --new-session \
        --hostname "workstation" \
        --proc /proc \
        --dev /dev \
        --dev-bind /dev/dri /dev/dri \
        --tmpfs /tmp \
        --tmpfs /dev/shm \
        --bind-try /tmp/.X11-unix /tmp/.X11-unix \
        --setenv DISPLAY "''${DISPLAY:-:0}" \
        --ro-bind /sys /sys \
        --ro-bind /nix /nix \
        --ro-bind /run/current-system /run/current-system \
        --ro-bind /etc/fonts /etc/fonts \
        --ro-bind /etc/resolv.conf /etc/resolv.conf \
        --ro-bind /etc/machine-id /etc/machine-id \
        --ro-bind /etc/passwd /etc/passwd \
        --ro-bind /etc/group /etc/group \
        --ro-bind /etc/hosts /etc/hosts \
        --ro-bind /run/opengl-driver /run/opengl-driver \
        --ro-bind "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt" /etc/ssl/certs/ca-certificates.crt \
        --bind "$ISOLATION_DIR" "$HOME/.config/spotify" \
        --bind "$ISOLATION_DIR-cache" "$HOME/.cache/spotify" \
        --dir "$HOME" \
        --dir "$XDG_RT" \
        --ro-bind-try "$XDG_RT/$WAYLAND_DISPLAY" "$XDG_RT/$WAYLAND_DISPLAY" \
        --ro-bind-try "$XDG_RT/pipewire-0" "$XDG_RT/pipewire-0" \
        --ro-bind-try "$XDG_RT/pulse" "$XDG_RT/pulse" \
        --bind-try "$XDG_RT/bus" "$XDG_RT/bus" \
        --setenv HOME "$HOME" \
        --setenv XDG_RUNTIME_DIR "$XDG_RT" \
        --setenv WAYLAND_DISPLAY "''${WAYLAND_DISPLAY:-wayland-0}" \
        --setenv XDG_SESSION_TYPE "wayland" \
        --setenv SPOTIFY_DISABLE_TELEMETRY "1" \
        --setenv HOSTNAME "workstation" \
        --setenv SSL_CERT_FILE /etc/ssl/certs/ca-certificates.crt \
        --setenv NIX_SSL_CERT_FILE /etc/ssl/certs/ca-certificates.crt \
        --setenv ELECTRON_DISABLE_CRASH_REPORTER "1" \
        ${pkgs.spotify}/bin/spotify \
          --ozone-platform=wayland \
          --enable-features=UseOzonePlatform,VaapiVideoDecoder,VaapiVideoEncoder \
          --enable-gpu-rasterization \
          --enable-zero-copy \
          --ignore-gpu-blocklist \
          "$@"
  '';
in
pkgs.stdenv.mkDerivation {
  name = "sandboxed-spotify-wayland";
  version = "2.1";
  dontUnpack = true;
  installPhase = ''
    mkdir -p $out/bin $out/share/applications
    ln -s ${pkgs.spotify}/share/icons $out/share/icons
    cp ${spotify-sandbox}/bin/spotify $out/bin/spotify
    chmod +x $out/bin/spotify
    cat > $out/share/applications/spotify.desktop << EOF
[Desktop Entry]
Type=Application
Name=Spotify
Comment=Spotify Music (Sandboxed)
Exec=$out/bin/spotify %u
Icon=spotify-client
Terminal=false
Categories=AudioVideo;Audio;Player;
StartupWMClass=Spotify
NoDisplay=false
EOF
  '';
}
