# stem2midi — one command that separates a track with demucs, then converts
# each pitched stem to MIDI with basic-pitch.
{ writeShellApplication
, demucs
, basic-pitch
}:
writeShellApplication {
  name = "stem2midi";
  runtimeInputs = [ demucs basic-pitch ];
  text = ''
    shopt -s nullglob

    out="./stem2midi-out"
    device="cpu"
    model="htdemucs"
    include_drums=0

    print_help() {
      cat <<'EOF'
    stem2midi — separate a track into stems (demucs) and convert each to MIDI (basic-pitch)

    Usage: stem2midi [options] <audio-file>...

    Options:
      -o DIR     Output directory (default: ./stem2midi-out)
      -d DEVICE  Compute device for demucs: cpu or cuda (default: cpu)
      -n MODEL   demucs model name (default: htdemucs)
      --all      Also convert the drums stem (percussive; usually poor as MIDI)
      -h, --help Show this help

    Output layout:
      <out>/demucs/<model>/<track>/<stem>.wav   separated stems
      <out>/midi/<track>/<stem>_basic_pitch.mid MIDI per stem
    EOF
    }

    files=()
    while [ $# -gt 0 ]; do
      case "$1" in
        -o) out="$2"; shift 2 ;;
        -d) device="$2"; shift 2 ;;
        -n) model="$2"; shift 2 ;;
        --all) include_drums=1; shift ;;
        -h|--help) print_help; exit 0 ;;
        -*) echo "stem2midi: unknown option: $1" >&2; exit 1 ;;
        *) files+=("$1"); shift ;;
      esac
    done

    if [ ''${#files[@]} -eq 0 ]; then
      echo "stem2midi: no input files given" >&2
      print_help >&2
      exit 1
    fi

    demucs_out="$out/demucs"

    for f in "''${files[@]}"; do
      if [ ! -f "$f" ]; then
        echo "stem2midi: no such file: $f" >&2
        exit 1
      fi

      echo "==> Separating stems: $f"
      demucs -d "$device" -n "$model" -o "$demucs_out" "$f"

      track="$(basename "''${f%.*}")"
      stemdir="$demucs_out/$model/$track"
      mididir="$out/midi/$track"
      mkdir -p "$mididir"

      for stem in "$stemdir"/*.wav; do
        name="$(basename "$stem" .wav)"
        if [ "$include_drums" -eq 0 ] && [ "$name" = "drums" ]; then
          echo "==> Skipping drums stem (percussive; pass --all to include)"
          continue
        fi
        echo "==> Converting to MIDI: $name"
        basic-pitch "$mididir" "$stem"
      done

      echo "==> Done: $track"
      echo "    stems: $stemdir"
      echo "    midi:  $mididir"
    done
  '';
}
