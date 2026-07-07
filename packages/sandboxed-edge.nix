{ pkgs, ... }:
let
  vomit-icon = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/twitter/twemoji/v14.0.2/assets/svg/1f92e.svg";
    hash = "sha256-oTcDe303TiVy/yFL2GNnXC4dyzXgPxEiuadP3ae6d1U=";
  };
  edge-launcher = pkgs.writeShellScriptBin "edge" ''
    ISOLATION_DIR="$HOME/.local/share/app-isolation/edge"
    mkdir -p "$ISOLATION_DIR"/.local/share/keyrings
    USER_ID=$(id -u)
    WAYLAND_SOCK=''${WAYLAND_DISPLAY:-wayland-0}
    exec ${pkgs.bubblewrap}/bin/bwrap \
      --unshare-all \
      --share-net \
      --die-with-parent \
      --new-session \
      --hostname "edge-prison" \
      --proc /proc \
      --dev /dev \
      --tmpfs /tmp \
      --tmpfs /dev/shm \
      --ro-bind /nix /nix \
      --ro-bind /run/current-system /run/current-system \
      --ro-bind /run/opengl-driver /run/opengl-driver \
      --ro-bind /etc/fonts /etc/fonts \
      --ro-bind /etc/ssl /etc/ssl \
      --ro-bind /etc/resolv.conf /etc/resolv.conf \
      --ro-bind /etc/machine-id /etc/machine-id \
      --ro-bind-try /etc/passwd /etc/passwd \
      --ro-bind-try /etc/dbus-1 /etc/dbus-1 \
      --ro-bind-try /usr/share/dbus-1 /usr/share/dbus-1 \
      --ro-bind-try /etc/static /etc/static \
      --dir /run/user/$USER_ID \
      --ro-bind-try /run/user/$USER_ID/$WAYLAND_SOCK /run/user/$USER_ID/$WAYLAND_SOCK \
      --ro-bind-try /run/user/$USER_ID/pulse /run/user/$USER_ID/pulse \
      --bind-try /run/user/$USER_ID/pipewire-0 /run/user/$USER_ID/pipewire-0 \
      --ro-bind /dev/dri /dev/dri \
      --bind "$ISOLATION_DIR" "$HOME" \
      --setenv HOME "$HOME" \
      --setenv XDG_RUNTIME_DIR "/run/user/$USER_ID" \
      --setenv WAYLAND_DISPLAY "$WAYLAND_SOCK" \
      --setenv XDG_SESSION_TYPE "wayland" \
      --setenv XDG_CURRENT_DESKTOP "sway" \
      -- \
      ${pkgs.dbus}/bin/dbus-run-session -- ${pkgs.bash}/bin/bash -c '
        eval $(${pkgs.gnome-keyring}/bin/gnome-keyring-daemon --start --components=secrets)
        export GNOME_KEYRING_CONTROL SSH_AUTH_SOCK
        exec ${pkgs.microsoft-edge}/bin/microsoft-edge \
          --ozone-platform=wayland \
          --enable-features=UseOzonePlatform \
          --enable-wayland-ime \
          "$@"
      ' -- "$@"
  '';
in
pkgs.stdenv.mkDerivation {
  pname = "sandboxed-edge-wayland";
  version = "1.0";
  phases = [ "installPhase" ];
  installPhase = ''
    mkdir -p $out/bin $out/share/applications $out/share/icons/hicolor/scalable/apps
    cp ${vomit-icon} $out/share/icons/hicolor/scalable/apps/edge-vomit.svg
    ln -s ${edge-launcher}/bin/edge $out/bin/edge
    cat > $out/share/applications/edge.desktop << EOF
[Desktop Entry]
Type=Application
Name=Edge (Prison)
Comment=Microsoft Edge (Strict Bubblewrap Isolation)
Exec=$out/bin/edge %u
Icon=edge-vomit
Terminal=false
Categories=Network;WebBrowser;
StartupWMClass=microsoft-edge
EOF
  '';
}

