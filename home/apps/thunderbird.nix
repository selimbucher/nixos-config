{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  profile = ".thunderbird/${config.thunderbird.profile}";
  addons = {
    "mail-look@selim.one" = pkgs.callPackage ../../pkgs/thunderbird-mail-look { };
  };
  # Add-ons this file used to install.
  retired = [
    "message-list@selim.one"
    "settings-button@selim.one"
  ];
in
{
  options.thunderbird.profile = lib.mkOption {
    type = lib.types.str;
    default = "default";
    description = ''
      Folder of the Thunderbird profile in ~/.thunderbird, the same on every
      device; profiles.ini below makes it the one Thunderbird opens. An existing
      profile (a random name like sjmnea7i.default) has to be renamed to it
      once, with Thunderbird closed, before switching.
    '';
  };

  config = {
    # Thunderbird opens this profile everywhere. Forced: Thunderbird may rewrite
    # the file, and on an existing install it's already there.
    home.file.".thunderbird/profiles.ini" = {
      force = true;
      text = lib.generators.toINI { } {
        General = {
          StartWithLastProfile = 1;
          Version = 2;
        };
        Profile0 = {
          Name = config.thunderbird.profile;
          IsRelative = 1;
          Path = config.thunderbird.profile;
          Default = 1;
        };
      };
    };

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
      + lib.concatMapStrings (id: ''
        run rm -f "$HOME/${profile}/extensions/${id}.xpi"
      '') retired
    );

    # Appended to the user.js that home/theme.nix writes.
    home.file."${profile}/user.js".text = ''
      // Enable add-ons dropped into the profile (the ones above) without a
      // confirmation prompt; the other install scopes stay auto-disabled.
      user_pref("extensions.autoDisableScopes", 14);
      // Archive on the mail server (its Archive folder, a subfolder per year)
      // instead of Local Folders.
      // (id1 is the first identity set up in the profile, me@selim.one.)
      user_pref("mail.identity.id1.archive_folder", "imap://me%40selim.one@mail.selim.one/Archive");
      user_pref("mail.identity.id1.archives_folder_picker_mode", "1");
      // Sender as display name only, the address when there is no name.
      user_pref("mail.addressDisplayFormat", 2);
      // Plain-text mail in the normal font, as Apple Mail shows it.
      user_pref("mail.fixed_width_messages", false);
      // A selected thread opens as a conversation: earlier messages as rows,
      // the newest in full (Thunderbird's own view, off by default).
      user_pref("mail.thread.conversation.enabled", true);
      // Menus without underlined access-key letters, like macOS.
      user_pref("ui.key.menuAccessKey", 0);
      // Toolbar buttons as icons only, without their names.
      user_pref("toolbar.unifiedtoolbar.buttonstyle", 2);
      // Images and other remote content in messages load without asking.
      user_pref("mailnews.message_display.disable_remote_image", false);
      // No tab bar while only one tab is open.
      user_pref("mail.tabs.autoHide", true);
      // Nothing in the message pane until a message is picked, instead of
      // Thunderbird's start page.
      user_pref("mailnews.start_page.enabled", false);
      // Where search and message actions go: mail, list, single, minimal or
      // reader; the folder pane: thunderbird, mail or colorful; its header:
      // hidden or quiet
      // (see pkgs/thunderbird-mail-look/src/experiment/implementation.js).
      user_pref("extensions.mail-look.layout", "mail");
      user_pref("extensions.mail-look.folders", "colorful");
      user_pref("extensions.mail-look.folderHeader", "hidden");
      // Sender logos from ~/Documents/Code/mail-logos, behind its path token;
      // empty shows initials only.
      user_pref("extensions.mail-look.logoBaseURL", "https://logos.selim.one/${inputs.secrets.mailLogosToken}/");
    '';

    # Appended to the userChrome.css that home/theme.nix writes.
    home.file."${profile}/chrome/userChrome.css".text =
      builtins.readFile ../../pkgs/thunderbird-mail-look/mail-look.css;
  };
}
