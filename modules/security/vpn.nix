{ pkgs, lib, userConfig, config, ... }:

{
  networking.wireguard.enable = true;
  systemd.tmpfiles.rules = [
    "L+ /etc/wireguard/mullvad.conf 0600 root systemd-network - ${config.sops.secrets.mullvad-conf.path}"
  ];

  networking.wg-quick.interfaces.mullvad = {
    configFile = "/etc/wireguard/mullvad.conf";
    # postUp is NOT used here — wg-quick ignores it when configFile is set.
    # Routing rules live in ExecStartPost below, which always fires.
    autostart = true;
  };

  systemd.services.wg-quick-mullvad = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig.ExecStartPost = let
      script = pkgs.writeShellScript "mullvad-post-up" ''
        ${pkgs.procps}/bin/sysctl -w net.ipv4.conf.all.src_valid_mark=1
        # Mullvad's wg-quick installs a catch-all at priority 5099
        # (not fwmark 0xca6c -> lookup 51820) that swallows Tailscale's CGNAT
        # range (100.64.0.0/10) and the controller's advertised subnet
        # (192.0.0.0/24) into table 51820, black-holing them.
        # Priority 5090 rules to lookup table 52 run before 5099, so
        # Tailscale wins for these ranges while everything else goes through Mullvad.
        # del-then-add: idempotent, no leak across mullvad-toggle cycles.
        # Also clean up stale priority-5100 rules from earlier versions of this script.
        ${pkgs.iproute2}/bin/ip rule del to 100.64.0.0/10 lookup 52 priority 5100 2>/dev/null || true
        ${pkgs.iproute2}/bin/ip rule del to 192.0.0.0/24 lookup 52 priority 5100 2>/dev/null || true
        ${pkgs.iproute2}/bin/ip rule del to 100.64.0.0/10 lookup 52 priority 5085 2>/dev/null || true
        ${pkgs.iproute2}/bin/ip rule add to 100.64.0.0/10 lookup 52 priority 5085
        ${pkgs.iproute2}/bin/ip rule del to 192.0.0.0/24 lookup 52 priority 5085 2>/dev/null || true
        ${pkgs.iproute2}/bin/ip rule add to 192.0.0.0/24 lookup 52 priority 5085
      '';
    in [ "+${script}" ];
  };

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
