#!/usr/bin/env bash
# Captures the game and composes captioned Play Store screenshots + feature graphics.
# Output: store/screenshots/<lang>/{phone,tablet7,tablet10}-N.png, store/graphics/feature-<lang>.png
set -euo pipefail
cd "$(dirname "$0")/.."
FONT="assets/fonts/Sora[wght].ttf"
BG="#0f0f0f"; ACCENT="#dafa9c"; EDGE="#383b36"
RAW=$(mktemp -d); trap 'rm -rf "$RAW"' EXIT

# level(0-based) state theme taps  — states picked so the queue and pocket are in use
SHOTS=("29 mid dark 3" "14 mid dark 2" "59 mid dark 2" "499 home dark 0" "119 mid light 2")
declare -A CAP=(
  [tr1]="Okları doğru sırayla çıkar" [tr2]="Sıradaki renk kapıdan geçer" [tr3]="Cep dolmasın, ileriyi düşün"
  [tr4]="1000 bölüm, internetsiz" [tr5]="Koyu ve açık tema"
  [en1]="Clear arrows in the right order" [en2]="The next color passes the gate" [en3]="Don't let the pocket fill up"
  [en4]="1000 levels, fully offline" [en5]="Dark and light themes")
declare -A TAG=([tr]="Ok Bulmacası" [en]="Arrow Puzzle")

capture() { # lang out w h level state theme taps
  XDG_DATA_HOME=$(mktemp -d) LANG=$1 LC_ALL=$1 godot --path . --script tests/capture_ui.gd -- "$2" "$3" "$4" "$5" "$6" "$7" "$8" >/dev/null 2>&1
}

frame() { # raw out W H caption
  local W=$3 H=$4 cap_h=$(( $4 * 19 / 100 )) shot_h=$(( $4 * 76 / 100 ))
  local r=$(( W / 22 )) sw=$(( shot_h * W / H ))
  local x=$(( (W - sw) / 2 )) y=$cap_h
  # raw shot has the target aspect, so the rounded mask is exactly sw x shot_h
  magick "$1" -resize "${sw}x${shot_h}!" \
    \( -size "${sw}x${shot_h}" xc:black -fill white -draw "roundrectangle 0,0 $((sw-1)),$((shot_h-1)) $r,$r" \) \
    -alpha off -compose CopyOpacity -composite "$RAW/framed.png"
  magick -size "${W}x${H}" "xc:$BG" \
    -fill "$EDGE" -draw "roundrectangle $((x-3)),$((y-3)) $((x+sw+2)),$((y+shot_h+2)) $((r+3)),$((r+3))" \
    \( -size "$(( W * 88 / 100 ))x$(( cap_h * 80 / 100 ))" -background none -fill "$ACCENT" -font "$FONT" \
       -gravity center caption:"$5" \) -gravity north -geometry "+0+$(( cap_h / 8 ))" -composite \
    "$RAW/framed.png" -gravity northwest -geometry "+${x}+${y}" -compose over -composite \
    -alpha off "$2"
}

for L in tr_TR.UTF-8 en_US.UTF-8; do
  l=${L:0:2}; mkdir -p "store/screenshots/$l"
  for n in 1 2 3 4 5; do
    read -r lv st th tp <<< "${SHOTS[$((n-1))]}"
    # phone 9:16, 7" tablet 10:16, 10" tablet 3:4 (all within Play's 2:1 limit)
    for spec in "phone 1080 1920" "tablet7 1200 1920" "tablet10 1536 2048"; do
      read -r kind W H <<< "$spec"
      capture "$L" "$RAW/raw.png" "$W" "$H" "$lv" "$st" "$th" "$tp"
      frame "$RAW/raw.png" "store/screenshots/$l/$kind-$n.png" "$W" "$H" "${CAP[$l$n]}"
    done
  done
  # feature graphic 1024x500: logo text left, gameplay crop right
  capture "$L" "$RAW/fg.png" 1080 1920 29 mid dark 3
  magick -size 1024x500 "xc:$BG" \
    \( -background none -fill white -font "$FONT" -pointsize 62 label:"Arrow Traffic" -trim +repage \) -gravity northwest -geometry +56+160 -composite \
    \( -background none -fill "$ACCENT" -font "$FONT" -pointsize 44 label:"${TAG[$l]}" -trim +repage \) -gravity northwest -geometry +58+280 -composite \
    \( "$RAW/fg.png" -crop 1000x1000+40+560 +repage -resize 400x400 \) -gravity east -geometry +36+0 -composite \
    -alpha off "store/graphics/feature-$l.png"
done
ls store/screenshots/* store/graphics
