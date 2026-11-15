# Free Download Manager 6, the vendor's Linux build. Not in nixpkgs (pkgs.fdm
# is an unrelated mail fetcher). The .deb comes from the vendor's apt
# repository (debrepo.freedownloadmanager.org, signed by the key the package's
# own postinst installs), by versioned pool path rather than the moving
# "6/latest" link, so the hash stays meaningful.
#
# The package is a CQtDeployer bundle under /opt/freedownloadmanager: its own
# Qt 6.10 (xcb and wayland platforms, gtk3 and xdg-portal themes), OpenSSL
# and ICU, with RUNPATH=$ORIGIN:$ORIGIN/lib, so only the system layer below
# Qt is wanted from nixpkgs; autoPatchelf wires it in. qt.conf points at the
# bundle's own lib/, plugins/ and qml/ relative to the binary, which is why
# the vendor's .desktop can exec fdm directly, without fdm.sh.
#
# Optional helpers FDM looks up on PATH at runtime (its Depends line):
# ffmpeg (merging video+audio streams), bubblewrap (sandboxing the Deno and
# Python it runs media-site parsers with) and xdg-utils (open folder / open
# file). deno and python3 too, so nixpkgs' are used instead of the builds FDM
# would otherwise download, which would need nix-ld.
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  brotli,
  dbus,
  fontconfig,
  freetype,
  glib,
  krb5,
  libglvnd,
  libpulseaudio,
  libxkbcommon,
  zlib,
  zstd,
  xorg,
  xcb-util-cursor,
  wayland,
  libdrm,
  gtk3,
  cairo,
  pango,
  gdk-pixbuf,
  atk,
  harfbuzz,
  pipewire,
  ffmpeg,
  bubblewrap,
  xdg-utils,
  deno,
  python3,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "free-download-manager";
  version = "6.36.0.7128";

  src = fetchurl {
    url = "https://debrepo.freedownloadmanager.org/pool/main/f/freedownloadmanager/freedownloadmanager_${finalAttrs.version}_amd64.deb";
    hash = "sha256-XLFyp12RtIuDC1JO/sojFXk0WJX833bVesaocwi9CDI=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
  ];

  # dlopen'ed by the bundled Qt Multimedia, not a NEEDED entry, so autoPatchelf
  # cannot find it on its own; dlopen searches the calling library's own
  # RUNPATH, which is why this is appendRunpaths (every ELF) and not
  # runtimeDependencies (executables only). Without it every start logs a
  # pipewire-0.3 complaint.
  appendRunpaths = [ "${lib.getLib pipewire}/lib" ];

  buildInputs = [
    stdenv.cc.cc.lib
    brotli.lib
    dbus
    fontconfig
    freetype
    glib
    krb5
    libglvnd
    libpulseaudio
    libxkbcommon
    zlib
    zstd
    xorg.libX11
    xorg.libxcb
    xorg.xcbutil
    xorg.xcbutilimage
    xorg.xcbutilkeysyms
    xorg.xcbutilrenderutil
    xorg.xcbutilwm
    xcb-util-cursor
    wayland
    libdrm
    # libqgtk3 platform theme
    gtk3
    cairo
    pango
    gdk-pixbuf
    atk
    harfbuzz
  ];

  unpackPhase = ''
    runHook preUnpack
    dpkg -x $src .
    runHook postUnpack
  '';

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt $out/bin $out/share/applications $out/share/pixmaps $out/share/metainfo
    cp -r opt/freedownloadmanager $out/opt/

    # Qt SQL drivers for databases FDM never opens (it uses sqlite), and the
    # TIFF image plugin: each would pull in a client library nixpkgs lacks
    # (libclntsh, libfbclient, libmimerapi, libmysqlclient.so.21, libtiff.so.5).
    rm $out/opt/freedownloadmanager/plugins/sqldrivers/libqsql{ibase,mimer,mysql,oci,odbc,psql}.so
    rm $out/opt/freedownloadmanager/plugins/imageformats/libqtiff.so
    # the vendor's env-setting launcher; the binary finds its bundle without it
    rm $out/opt/freedownloadmanager/fdm.sh

    # Left unset, fdm sets QT_QPA_PLATFORM=xcb;wayland itself and takes xcb,
    # which loads fine on Hyprland but never maps a window; the bundled
    # wayland plugin shows it within a second.
    makeWrapper $out/opt/freedownloadmanager/fdm $out/bin/fdm \
      --set-default QT_QPA_PLATFORM wayland \
      --prefix PATH : ${
        lib.makeBinPath [
          ffmpeg
          bubblewrap
          xdg-utils
          deno
          python3
        ]
      }

    install -Dm644 opt/freedownloadmanager/icon.png $out/share/pixmaps/freedownloadmanager.png
    install -Dm644 usr/share/appdata/freedownloadmanager.appdata.xml $out/share/metainfo/
    substitute usr/share/applications/freedownloadmanager.desktop $out/share/applications/freedownloadmanager.desktop \
      --replace-fail "Exec=/opt/freedownloadmanager/fdm" "Exec=$out/bin/fdm %U" \
      --replace-fail "Icon=/opt/freedownloadmanager/icon.png" "Icon=freedownloadmanager"

    runHook postInstall
  '';

  meta = {
    description = "Download accelerator and organizer (Free Download Manager 6)";
    homepage = "https://www.freedownloadmanager.org/";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "fdm";
  };
})
