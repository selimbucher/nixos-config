usage() { cat <<'U'
transcribe <file>... [-l <lang>] [-m <model>] [--translate]
  -l de|en|fr|...   language (default: auto-detect)
  -m <model>        tiny|base|small|medium|large-v3|large-v3-turbo (default;
                    medium with --translate)
  --translate       output English instead of the spoken language
Writes <file>.txt and <file>.srt next to each input.
U
}

lang=auto
model=
extra=()
files=()
while (($#)); do
  case $1 in
    -l) lang=$2; shift 2 ;;
    -m) model=$2; shift 2 ;;
    --translate) extra+=(--translate); shift ;;
    -h|--help) usage; exit 0 ;;
    *) files+=("$1"); shift ;;
  esac
done
((${#files[@]})) || { usage; exit 1; }
# turbo was trained without translation data and ignores --translate
[[ -n $model ]] || if ((${#extra[@]})); then model=medium; else model=large-v3-turbo; fi

models=${XDG_CACHE_HOME:-$HOME/.cache}/whisper
mfile=$models/ggml-$model.bin
if [[ ! -f $mfile ]]; then
  mkdir -p "$models"
  echo "downloading model $model (once) ..." >&2
  curl -fL --progress-bar -o "$mfile.part" \
    "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-$model.bin"
  mv "$mfile.part" "$mfile"
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
for f in "${files[@]}"; do
  out=${f%.*}
  ffmpeg -nostdin -loglevel error -y -i "$f" -vn -ar 16000 -ac 1 -c:a pcm_s16le "$tmp/a.wav"
  whisper-cli -m "$mfile" -f "$tmp/a.wav" -l "$lang" "${extra[@]}" \
    -otxt -osrt -of "$out" -np -t "$(nproc)"
  echo "-> $out.txt, $out.srt" >&2
done
