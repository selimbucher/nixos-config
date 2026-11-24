{ lib, ... }:

# Speaker EQ for the Framework Laptop 13 Pro's internal speakers, measured
# 2026-11-19 with a UMIK-1: average over six head positions at ~50 cm, laptop
# on a table, room reflections gated out, near field below 500 Hz. Both
# speakers measure within 1 dB, so they share one EQ. Smart filter on the
# speaker sink only; headphones, Bluetooth and USB outputs are untouched.
#
# speakers/speaker-eq-volume.lua moves the high-pass, loudness shelf and
# preamp with the volume. The values below are what the filter starts with.
let
  speaker = "alsa_output.pci-0000_c1_00.6.HiFi__Speaker__sink";

  stages = [
    # 0 Hz high shelf = plain gain, headroom for the +2 dB band
    { name = "pre"; label = "bq_highshelf"; freq = 0; q = 1.0; gain = -1.45; }
    # keeps sub-bass excursion (no output, all distortion) off the drivers
    { name = "hp"; label = "bq_highpass"; freq = 150; q = 0.707; gain = 0; }
    # loudness lift, 0 dB until the volume script sets it
    { name = "ls"; label = "bq_lowshelf"; freq = 228; q = 0.53; gain = 0; }
    { name = "pk1"; label = "bq_peaking"; freq = 638; q = 3.0; gain = -3.4; }   # cabinet resonance
    { name = "pk2"; label = "bq_peaking"; freq = 1725; q = 2.32; gain = 2.0; }
    { name = "pk3"; label = "bq_peaking"; freq = 2501; q = 3.0; gain = -1.05; }
    { name = "pk4"; label = "bq_peaking"; freq = 4177; q = 3.0; gain = -10.36; } # the honk
  ];

  nodes = ch: map (s: {
    type = "builtin";
    name = "${s.name}_${ch}";
    inherit (s) label;
    control = { Freq = s.freq; Q = s.q; Gain = s.gain; };
  }) stages;
  links = ch: lib.zipListsWith (a: b: {
    output = "${a.name}_${ch}:Out";
    input = "${b.name}_${ch}:In";
  }) stages (lib.tail stages);
  first = (lib.head stages).name;
  last = (lib.last stages).name;
in
{
  services.pipewire.extraConfig.pipewire."60-speaker-eq" = {
    "context.modules" = [{
      name = "libpipewire-module-filter-chain";
      flags = [ "nofail" ];
      args = {
        "node.description" = "Speaker EQ";
        "media.name" = "Speaker EQ";
        "filter.graph" = {
          nodes = nodes "l" ++ nodes "r";
          links = links "l" ++ links "r";
          inputs = [ "${first}_l:In" "${first}_r:In" ];
          outputs = [ "${last}_l:Out" "${last}_r:Out" ];
        };
        "audio.channels" = 2;
        "audio.position" = [ "FL" "FR" ];
        "capture.props" = {
          "node.name" = "effect_input.speaker_eq";
          "media.class" = "Audio/Sink";
          "node.link-group" = "speaker_eq";
          "filter.smart" = true;
          "filter.smart.name" = "speaker_eq";
          "filter.smart.target" = { "node.name" = speaker; };
          "priority.session" = -1;
        };
        "playback.props" = {
          "node.name" = "effect_output.speaker_eq";
          "node.passive" = true;
          "node.link-group" = "speaker_eq";
        };
      };
    }];
  };

  services.pipewire.wireplumber.extraScripts."speaker-eq-volume.lua" =
    builtins.replaceStrings [ "@speaker@" ] [ speaker ] (builtins.readFile ./speakers/speaker-eq-volume.lua);
  services.pipewire.wireplumber.extraConfig."60-speaker-eq-volume" = {
    "wireplumber.components" = [{
      name = "speaker-eq-volume.lua";
      type = "script/lua";
      provides = "custom.speaker-eq-volume";
    }];
    # optional: a script error must not take WirePlumber down with it
    "wireplumber.profiles".main."custom.speaker-eq-volume" = "optional";
  };
}
