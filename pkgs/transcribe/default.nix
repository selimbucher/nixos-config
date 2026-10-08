{ writeShellApplication, whisper-cpp-vulkan, ffmpeg-headless, curl }:
writeShellApplication {
  name = "transcribe";
  runtimeInputs = [ whisper-cpp-vulkan ffmpeg-headless curl ];
  text = builtins.readFile ./transcribe.sh;
}
