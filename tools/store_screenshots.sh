#!/usr/bin/env bash
# Captures the game and composes captioned Play Store screenshots + feature graphics.
# Output: store/screenshots/<lang>/{phone,tablet7,tablet10}-N.png,
#         store/screenshots/<lang>/foldable-{1,folded-10x16,unfolded-1x1,unfolded-4x3}.png,
#         store/graphics/feature-<lang>.png
# Needs Godot 4 and ImageMagick (7 `magick`, or 6 `convert`). Without a display it runs Godot under `xvfb-run`.
set -euo pipefail
cd "$(dirname "$0")/.."
FONT="assets/fonts/Sora[wght].ttf"
BG="#0f0f0f"; ACCENT="#dafa9c"; EDGE="#383b36"
RAW=$(mktemp -d); trap 'rm -rf "$RAW"' EXIT

if command -v magick >/dev/null; then IM=(magick); elif command -v convert >/dev/null; then IM=(convert)
else echo "ImageMagick not found (magick or convert)" >&2; exit 1; fi
GODOT=(godot --rendering-driver opengl3)
if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
  command -v xvfb-run >/dev/null || { echo "No display and no xvfb-run: cannot render captures" >&2; exit 1; }
  GODOT=(xvfb-run -a "${GODOT[@]}")
fi

# level(0-based) state theme taps — hint highlight, queue+pocket in use, level select with stars, home, light theme
SHOTS=("29 hint dark 2" "14 mid dark 2" "89 levels dark 0" "499 home dark 0" "119 mid light 2")
# "\n" is ImageMagick's line break: set by hand so lines stay balanced (portrait); the landscape foldable drops them and rewraps
declare -A CAP=(
  [tr1]='İpucu doğru\noku gösterir' [tr2]='Sıradaki renk\nkapıdan geçer' [tr3]='1000 bölüm,\n3 yıldız topla'
  [tr4]='İnternetsiz,\nkendi hızında' [tr5]='Koyu ve\naçık tema'
  [en1]='Hints show\nthe right arrow' [en2]='The next color\npasses the gate' [en3]='1000 levels,\ncollect 3 stars'
  [en4]='Offline, at\nyour own pace' [en5]='Dark and\nlight themes')
declare -A TAG=([tr]="Ok Bulmacası" [en]="Arrow Puzzle")

capture() { # lang out w h level state theme taps
  local data; data=$(mktemp -d -p "$RAW")
  XDG_DATA_HOME=$data LANG=$1 LC_ALL=$1 "${GODOT[@]}" --path . --script tests/capture_ui.gd -- "$2" "$3" "$4" "$5" "$6" "$7" "$8" >/dev/null 2>&1
  [[ -s "$2" ]] || { echo "capture failed: $*" >&2; exit 1; }
}

fit() { # w h text... -> largest pointsize at which every caption fits a w x h box (same size across a set)
  local w=$1 h=$2 best="" p; shift 2
  for t in "$@"; do
    p=$("${IM[@]}" -size "${w}x${h}" -font "$FONT" caption:"$t" -format '%[caption:pointsize]' info:)
    best=$(awk -v a="$p" -v b="$best" 'BEGIN { print (b == "" || a + 0 < b + 0) ? int(a) : b }')
  done
  echo "$best"
}

rounded() { # raw out w h radius — resize the shot and round its corners
  "${IM[@]}" "$1" -resize "${3}x${4}!" \
    \( -size "${3}x${4}" xc:black -fill white -draw "roundrectangle 0,0 $(($3-1)),$(($4-1)) $5,$5" \) \
    -alpha off -compose CopyOpacity -composite "$2"
}

frame() { # raw out W H caption pointsize — caption on top, shot below
  local W=$3 H=$4 cap_h=$(( $4 * 19 / 100 )) shot_h=$(( $4 * 76 / 100 ))
  local r=$(( W / 22 )) sw=$(( shot_h * W / H ))
  local x=$(( (W - sw) / 2 )) y=$cap_h
  # raw shot has the target aspect, so the rounded mask is exactly sw x shot_h
  rounded "$1" "$RAW/framed.png" "$sw" "$shot_h" "$r"
  "${IM[@]}" -size "${W}x${H}" "xc:$BG" \
    -fill "$EDGE" -draw "roundrectangle $((x-3)),$((y-3)) $((x+sw+2)),$((y+shot_h+2)) $((r+3)),$((r+3))" \
    \( -size "$(( W * 88 / 100 ))x$(( cap_h * 80 / 100 ))" -background none -fill "$ACCENT" -font "$FONT" \
       -pointsize "$6" -gravity center caption:"$5" \) -gravity north -geometry "+0+$(( cap_h / 8 ))" -composite \
    "$RAW/framed.png" -gravity northwest -geometry "+${x}+${y}" -compose over -composite \
    -alpha off "$2"
}

side() { # lang out W H level state theme taps caption — landscape: caption left, shot right
  local W=$3 H=$4 shot_h=$(( $4 * 90 / 100 )); local sw=$(( shot_h * 5 / 6 ))
  local r=$(( sw / 22 )) y=$(( (H - shot_h) / 2 )); local x=$(( W - sw - y ))
  capture "$1" "$RAW/side.png" "$sw" "$shot_h" "$5" "$6" "$7" "$8"
  rounded "$RAW/side.png" "$RAW/framed.png" "$sw" "$shot_h" "$r"
  "${IM[@]}" -size "${W}x${H}" "xc:$BG" \
    -fill "$EDGE" -draw "roundrectangle $((x-3)),$((y-3)) $((x+sw+2)),$((y+shot_h+2)) $((r+3)),$((r+3))" \
    \( -size "$(( x * 80 / 100 ))x$(( H * 60 / 100 ))" -background none -fill "$ACCENT" -font "$FONT" \
       -gravity center caption:"${9//\\n/ }" \) -gravity west -geometry "+$(( x / 10 ))+0" -composite \
    "$RAW/framed.png" -gravity northwest -geometry "+${x}+${y}" -compose over -composite \
    -alpha off "$2"
}

for L in tr_TR.UTF-8 en_US.UTF-8; do
  l=${L:0:2}; out="store/screenshots/$l"; mkdir -p "$out"
  caps=(); for n in 1 2 3 4 5; do caps+=("${CAP[$l$n]}"); done
  # phone 9:16, 7" tablet 10:16, 10" tablet 3:4 (all within Play's 2:1 limit), foldable 9:16 and 1:1
  for spec in "phone 1080 1920" "tablet7 1200 1920" "tablet10 1536 2048" "foldable 2160 3840" "unfolded 2160 2160"; do
    read -r kind W H <<< "$spec"
    pt=$(fit "$(( W * 88 / 100 ))" "$(( H * 19 / 100 * 80 / 100 ))" "${caps[@]}")
    for n in 1 2 3 4 5; do
      # foldables get one shot each (the hint shot); the folded 10:16 one is the 7" tablet shot
      [[ $kind == foldable || $kind == unfolded ]] && (( n > 1 )) && continue
      read -r lv st th tp <<< "${SHOTS[$((n-1))]}"
      capture "$L" "$RAW/raw.png" "$W" "$H" "$lv" "$st" "$th" "$tp"
      case $kind in
        foldable) dest="$out/foldable-1.png" ;;
        unfolded) dest="$out/foldable-unfolded-1x1.png" ;;
        *) dest="$out/$kind-$n.png" ;;
      esac
      frame "$RAW/raw.png" "$dest" "$W" "$H" "${CAP[$l$n]}" "$pt"
    done
  done
  cp "$out/tablet7-1.png" "$out/foldable-folded-10x16.png"
  read -r lv st th tp <<< "${SHOTS[0]}"
  side "$L" "$out/foldable-unfolded-4x3.png" 2880 2160 "$lv" "$st" "$th" "$tp" "${CAP[${l}1]}"
  # feature graphic 1024x500: logo text left, board crop (with the hint highlight, pocket label left out) right
  capture "$L" "$RAW/fg.png" 1080 1920 29 hint dark 2
  "${IM[@]}" -size 1024x500 "xc:$BG" \
    \( -background none -fill white -font "$FONT" -pointsize 62 label:"Arrow Traffic" -trim +repage \) -gravity northwest -geometry +56+160 -composite \
    \( -background none -fill "$ACCENT" -font "$FONT" -pointsize 44 label:"${TAG[$l]}" -trim +repage \) -gravity northwest -geometry +58+280 -composite \
    \( "$RAW/fg.png" -crop 940x940+70+555 +repage -resize 400x400 \) -gravity east -geometry +36+0 -composite \
    -alpha off "store/graphics/feature-$l.png"
done
ls store/screenshots/* store/graphics
