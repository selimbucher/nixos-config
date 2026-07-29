# Cloud drive client — WebDAV remote for drive.selim.one (rclone serve webdav
# on the hetzner box), auto-mounted at ~/Drive with full VFS caching so it
# behaves like a local folder.
#
# The password is NOT in the store: rclone-config.service reads it from
# ~/.secrets/drive-webdav-pass at activation (plaintext; rclone obscures it on
# inject). Bootstrap on a new machine:
#   install -dm700 ~/.secrets && printf '%s' '<password>' > ~/.secrets/drive-webdav-pass
{ config, ... }:
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
      secrets.pass = "${config.home.homeDirectory}/.secrets/drive-webdav-pass";
      mounts."" = {
        mountPoint = "${config.home.homeDirectory}/Drive";
      };
    };
  };
}
