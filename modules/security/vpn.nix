{ pkgs, lib, userConfig, config, ... }:

{
  networking.wireguard.enable = true;
  systemd.tmpfiles.rules = [
    "L+ /etc/wireguard/mullvad.conf 0600 root systemd-network - ${config.sops.secrets.mullvad-conf.path}"
  ];

  networking.wg-quick.interfaces.mullvad = {
    configFile = "/etc/wireguard/mullvad.conf";
    postUp = [''
      ${pkgs.procps}/bin/sysctl -w net.ipv4.conf.all.src_valid_mark=1
      # Mullvad's wg-quick installs catch-all rules at priority 5198/5199 that
      # swallow Tailscale's CGNAT range (100.64.0.0/10) and the controller's
      # advertised subnet (192.0.0.0/24) into table 51820, black-holing them.
      # These run AFTER that, at a lower priority (5100), so table 52 wins.
      # postUp fires on every Mullvad start, so it survives the route reshuffle
      # that a NetworkManager dispatcher (link-event only) missed.
      # del-then-add: idempotent, no leak across mullvad-toggle cycles.
      ${pkgs.iproute2}/bin/ip rule del to 100.64.0.0/10 lookup 52 priority 5100 2>/dev/null || true
      ${pkgs.iproute2}/bin/ip rule add to 100.64.0.0/10 lookup 52 priority 5100
      ${pkgs.iproute2}/bin/ip rule del to 192.0.0.0/24 lookup 52 priority 5100 2>/dev/null || true
      ${pkgs.iproute2}/bin/ip rule add to 192.0.0.0/24 lookup 52 priority 5100
    ''];
    autostart = true;
  };

  # Use this if debugging mullvad setup is necessary
  # systemd.services.wg-quick-mullvad.wantedBy = lib.mkForce [ ];
  systemd.services.wg-quick-mullvad.wantedBy = [ "multi-user.target" ];

  environment.systemPackages = with pkgs; [
    wireguard-tools
    (writeShellScriptBin "mullvad-toggle" ''
      if systemctl is-active --quiet wg-quick-mullvad; then
        sudo systemctl stop wg-quick-mullvad
        echo "VPN disconnected"
      else
        sudo systemctl start wg-quick-mullvad
        echo "VPN connected"
      fi
    '')
    (writeShellScriptBin "mullvad-status" ''
      if systemctl is-active --quiet wg-quick-mullvad; then
        echo "Connected"
      else
        echo "Disconnected"
      fi
    '')
  ];
}
