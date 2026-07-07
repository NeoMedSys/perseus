{ pkgs, ... }:
let
  poop-icon = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/twitter/twemoji/v14.0.2/assets/svg/1f4a9.svg";
    hash = "sha256-5ymsznqBdL7JWtg0p7C+3OdXiB8AATTuas64sQ5KaFs=";
  };
  teams-launcher = pkgs.writeShellScriptBin "teams" ''
    ISOLATION_DIR="$HOME/.local/share/app-isolation/teams"
    mkdir -p "$ISOLATION_DIR"/.local/share/keyrings
    USER_ID=$(id -u)
    WAYLAND_SOCK=''${WAYLAND_DISPLAY:-wayland-0}
    XDG_RT="/run/user/$USER_ID"
    # Filtered session bus: portals only
    PROXY_DIR="$XDG_RT/teams-prison"
    mkdir -p "$PROXY_DIR"
    PROXY_BUS="$PROXY_DIR/bus"
    rm -f "$PROXY_BUS"
    ${pkgs.xdg-dbus-proxy}/bin/xdg-dbus-proxy \
      "unix:path=$XDG_RT/bus" \
      "$PROXY_BUS" \
      --filter \
      --talk=org.freedesktop.portal.Desktop \
      --talk=org.freedesktop.portal.Documents \
      --talk=org.freedesktop.Notifications \
      --call=org.freedesktop.portal.Desktop=* \
      --broadcast=org.freedesktop.portal.Desktop=* &
    PROXY_PID=$!
    trap "kill $PROXY_PID 2>/dev/null" EXIT
    # Wait for proxy socket
    for i in $(seq 1 50); do
      [ -S "$PROXY_BUS" ] && break
      sleep 0.1
    done
    ${pkgs.bubblewrap}/bin/bwrap \
      --unshare-all \
      --share-net \
      --die-with-parent \
      --new-session \
      --hostname "teams-prison" \
      --proc /proc \
      --dev /dev \
      --dev-bind /dev/dri /dev/dri \
      --ro-bind-try /dev/video0 /dev/video0 \
      --ro-bind-try /dev/video1 /dev/video1 \
      --tmpfs /tmp \
      --tmpfs /dev/shm \
      --ro-bind /nix /nix \
      --ro-bind /run/current-system /run/current-system \
      --ro-bind /run/opengl-driver /run/opengl-driver \
      --ro-bind /run/dbus /run/dbus \
      --ro-bind /sys /sys \
      --ro-bind /etc/fonts /etc/fonts \
      --ro-bind /etc/ssl /etc/ssl \
      --ro-bind /etc/resolv.conf /etc/resolv.conf \
      --ro-bind /etc/machine-id /etc/machine-id \
      --ro-bind-try /etc/passwd /etc/passwd \
      --ro-bind-try /etc/group /etc/group \
      --ro-bind-try /etc/dbus-1 /etc/dbus-1 \
      --ro-bind-try /usr/share/dbus-1 /usr/share/dbus-1 \
      --ro-bind-try /etc/static /etc/static \
      --dir "$XDG_RT" \
      --ro-bind-try "$XDG_RT/$WAYLAND_SOCK" "$XDG_RT/$WAYLAND_SOCK" \
      --ro-bind-try "$XDG_RT/pulse" "$XDG_RT/pulse" \
      --bind-try "$XDG_RT/pipewire-0" "$XDG_RT/pipewire-0" \
      --bind "$PROXY_BUS" "$XDG_RT/bus" \
      --bind "$ISOLATION_DIR" "$HOME" \
      --setenv HOME "$HOME" \
      --setenv XDG_RUNTIME_DIR "$XDG_RT" \
      --setenv WAYLAND_DISPLAY "$WAYLAND_SOCK" \
      --setenv XDG_SESSION_TYPE "wayland" \
      --setenv XDG_CURRENT_DESKTOP "sway" \
      --setenv DBUS_SESSION_BUS_ADDRESS "unix:path=$XDG_RT/bus" \
      -- \
      ${pkgs.teams-for-linux}/bin/teams-for-linux \
        --ozone-platform=wayland \
        --enable-features=UseOzonePlatform,WebRTCPipeWireCapturer,WebRtcPipeWireCamera \
        --enable-wayland-ime \
        "$@"
  '';
in
pkgs.stdenv.mkDerivation {
  pname = "sandboxed-teams-wayland";
  version = "1.5";
  phases = [ "installPhase" ];
  installPhase = ''
    mkdir -p $out/bin $out/share/applications $out/share/icons/hicolor/scalable/apps
    ln -s ${teams-launcher}/bin/teams $out/bin/teams
    cp ${poop-icon} $out/share/icons/hicolor/scalable/apps/teams-poop.svg
    cat > $out/share/applications/teams.desktop << EOF
[Desktop Entry]
Type=Application
Name=Teams (Prison)
Comment=Microsoft Teams (Strict Bubblewrap Isolation)
Exec=$out/bin/teams %u
Icon=teams-poop
Terminal=false
MimeType=x-scheme-handler/msteams;
Categories=Network;InstantMessaging;
StartupWMClass=teams-for-linux
EOF
  '';
}
