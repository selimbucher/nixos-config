# Cloud drive client — WebDAV remote for drive.selim.one (rclone serve webdav
# on the hetzner box), auto-mounted at ~/Drive with full VFS caching so it
# behaves like a local folder.
#
# The password comes from the private nixos-secrets flake (like hetznerIp), so
# a fresh machine needs no bootstrap. writeText puts it in the store —
# acceptable on these single-user hosts; rclone-config.service obscures it
# into rclone.conf at activation.
{ inputs, config, pkgs, ... }:
{
  programs.rclone = {
    enable = true;
    remotes.drive = {
      config = {
        type = "webdav";
        url = "https://drive.selim.one";
        vendor = "rclone";
        user = "selim";
      };
      secrets.pass = "${pkgs.writeText "drive-webdav-pass" inputs.secrets.driveWebdavPass}";
      mounts."" = {
        enable = true;
        mountPoint = "${config.home.homeDirectory}/Drive";
      };
    };
  };
}
