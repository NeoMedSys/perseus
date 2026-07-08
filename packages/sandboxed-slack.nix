{ pkgs, ... }:
let
  xdg-open-portal = pkgs.writeShellScriptBin "xdg-open" ''
    exec ${pkgs.glib}/bin/gdbus call --session \
      --dest org.freedesktop.portal.Desktop \
      --object-path /org/freedesktop/portal/desktop \
      --method org.freedesktop.portal.OpenURI.OpenURI \
      "" "$1" "{}" >/dev/null
  '';
  slack-sandbox = pkgs.writeShellScriptBin "slack" ''
    ISOLATION_DIR="$HOME/.local/share/app-isolation/slack"
    mkdir -p "$ISOLATION_DIR" "$ISOLATION_DIR-tmp"
    mkdir -p "$HOME/Downloads"
    USER_ID=$(id -u)
    XDG_RT="/run/user/$USER_ID"
    WAYLAND_SOCK=''${WAYLAND_DISPLAY:-wayland-0}
    # Filtered session bus: portals + notifications only, own systemd unit
    PROXY_DIR="$XDG_RT/slack-prison"
    mkdir -p "$PROXY_DIR"
    PROXY_BUS="$PROXY_DIR/bus"
    if [ ! -S "$PROXY_BUS" ]; then
      rm -f "$PROXY_BUS"
      ${pkgs.systemd}/bin/systemd-run --user --collect \
        --unit=slack-dbus-proxy \
        ${pkgs.xdg-dbus-proxy}/bin/xdg-dbus-proxy \
          "unix:path=$XDG_RT/bus" \
          "$PROXY_BUS" \
          --filter \
          --talk=org.freedesktop.portal.Desktop \
          --talk=org.freedesktop.portal.Documents \
          --talk=org.freedesktop.Notifications \
          --call=org.freedesktop.portal.Desktop=* \
          --broadcast=org.freedesktop.portal.Desktop=*
      for i in $(seq 1 50); do
        [ -S "$PROXY_BUS" ] && break
        sleep 0.1
      done
    fi
    exec ${pkgs.systemd}/bin/systemd-run \
      --user --scope --collect \
      --unit=sandboxed-slack-$(date +%s) \
      -p MemoryHigh=4G \
      -p MemoryMax=6G \
      ${pkgs.bubblewrap}/bin/bwrap \
        --unshare-all \
        --share-net \
        --die-with-parent \
        --new-session \
        --hostname "workstation" \
        --proc /proc \
        --dev /dev \
        --dev-bind /dev/dri /dev/dri \
        --dev-bind-try /dev/video0 /dev/video0 \
        --dev-bind-try /dev/video1 /dev/video1 \
        --dev-bind-try /dev/video2 /dev/video2 \
        --dev-bind-try /dev/video3 /dev/video3 \
        --bind "$ISOLATION_DIR-tmp" /tmp \
        --tmpfs /dev/shm \
        --ro-bind /sys /sys \
        --ro-bind /run/dbus /run/dbus \
        --ro-bind /nix /nix \
        --ro-bind /run/current-system /run/current-system \
        --ro-bind /etc /etc \
        --ro-bind /run/opengl-driver /run/opengl-driver \
        --bind "$ISOLATION_DIR" "$HOME/.config/Slack" \
        --bind "$HOME/Downloads" "$HOME/Downloads" \
        --dir "$HOME" \
        --bind-try /tmp/.X11-unix /tmp/.X11-unix \
        --dir "$XDG_RT" \
        --bind-try "$XDG_RT/$WAYLAND_SOCK" "$XDG_RT/$WAYLAND_SOCK" \
        --bind-try "$XDG_RT/pipewire-0" "$XDG_RT/pipewire-0" \
        --bind-try "$XDG_RT/pulse" "$XDG_RT/pulse" \
        --bind "$PROXY_BUS" "$XDG_RT/bus" \
        --setenv HOME "$HOME" \
        --setenv PATH "${xdg-open-portal}/bin:/run/current-system/sw/bin" \
        --setenv XDG_RUNTIME_DIR "$XDG_RT" \
        --setenv WAYLAND_DISPLAY "$WAYLAND_SOCK" \
        --setenv XDG_CURRENT_DESKTOP "niri" \
        --setenv XDG_SESSION_TYPE "wayland" \
        --setenv DBUS_SESSION_BUS_ADDRESS "unix:path=$XDG_RT/bus" \
        --setenv DISPLAY "''${DISPLAY:-:0}" \
        --setenv SLACK_DISABLE_TELEMETRY "1" \
        --setenv HOSTNAME "workstation" \
        ${pkgs.slack}/bin/slack \
          --no-sandbox \
          --enable-features=UseOzonePlatform,WebRTCPipeWireCapturer,WebRtcPipeWireCamera \
          --ozone-platform=wayland \
          --enable-wayland-ime \
          --force-device-scale-factor=1.0 \
          "$@"
  '';
in
pkgs.stdenv.mkDerivation {
  name = "sandboxed-slack-wayland";
  version = "2.2";
  dontUnpack = true;
  installPhase = ''
    mkdir -p $out/bin $out/share/applications
    ln -s ${pkgs.slack}/share/icons $out/share/icons
    cp ${slack-sandbox}/bin/slack $out/bin/slack
    chmod +x $out/bin/slack
    cat > $out/share/applications/slack.desktop << EOF
[Desktop Entry]
Type=Application
Name=Slack
Comment=Slack Desktop (Sandboxed)
Exec=$out/bin/slack %u
Icon=slack
Terminal=false
MimeType=x-scheme-handler/slack;
Categories=Network;InstantMessaging;
StartupWMClass=Slack
NoDisplay=false
EOF
  '';
}
