{ pkgs, lib, inputs, ... }:
let
  # Same profile as home/theme.nix.
  profile = ".thunderbird/sjmnea7i.default";
  addons = {
    "settings-button@selim.one" = pkgs.callPackage ../../pkgs/thunderbird-settings-button { };
    "message-list@selim.one" = pkgs.callPackage ../../pkgs/thunderbird-message-list { };
  };
in
{
  # Copied rather than linked: Thunderbird spots a changed add-on by its mtime,
  # and every file in the nix store has the same one.
  home.activation.thunderbirdAddons = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    lib.concatStrings (
      lib.mapAttrsToList (id: xpi: ''
        dest="$HOME/${profile}/extensions/${id}.xpi"
        if ! ${pkgs.diffutils}/bin/cmp -s ${xpi} "$dest"; then
          run mkdir -p "$(dirname "$dest")"
          run install -m 0644 ${xpi} "$dest"
        fi
      '') addons
    )
  );

  # Appended to the user.js that home/theme.nix writes.
  home.file."${profile}/user.js".text = ''
    // Enable add-ons dropped into the profile (the ones above) without a
    // confirmation prompt; the other install scopes stay auto-disabled.
    user_pref("extensions.autoDisableScopes", 14);
    // Sender as display name only, the address when there is no name.
    user_pref("mail.addressDisplayFormat", 2);
    // Look of the message list: mail, tiles, proton, compact or cards.
    user_pref("extensions.message-list.variant", "mail");
    // Sender logos from ~/Documents/Code/mail-logos, behind its path token;
    // empty shows initials only.
    user_pref("extensions.message-list.logoBaseURL", "https://logos.selim.one/${inputs.secrets.mailLogosToken}/");
  '';

  # Appended to the userChrome.css that home/theme.nix writes.
  home.file."${profile}/chrome/userChrome.css".text =
    builtins.readFile ../../pkgs/thunderbird-message-list/message-list.css;
}
