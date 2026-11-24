# The unlock screen of encrypted hosts (modules/plymouth.nix). gen.py draws the
# images from the wallpaper; they can't follow kiwi's at boot, the disk is
# still locked.
{ runCommand, python3, quicksand, wallpaper }:

runCommand "plymouth-theme-login" {
  nativeBuildInputs = [ (python3.withPackages (p: [ p.pillow p.numpy ])) ];
} ''
  dir=$out/share/plymouth/themes/login
  mkdir -p $dir
  python3 ${./gen.py} $dir ${wallpaper} ${quicksand}/share/fonts/truetype/Quicksand-Bold.ttf
  cp ${./login.script} $dir/login.script
  cat > $dir/login.plymouth <<EOF
  [Plymouth Theme]
  Name=login
  Description=macOS-style unlock screen
  ModuleName=script

  [script]
  ImageDir=$dir
  ScriptFile=$dir/login.script
  EOF
''
