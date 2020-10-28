#!/usr/bin/env bash
# Playback using mpv and ffmpeg, with picture-in-picture screenshot
# Invoke with a `date`-compatible timestamp expression. E.g. "30 days ago"

timestamp="today"
tmpdir="$(mktemp -d /tmp/.$(basename "$0").XXXXX)"

if [ "0" != "$#" ]; then
  timestamp="$1"
fi

pids=()
echo "Spawning jobs..."
for folder in ~/automatic_webcam_pics/$(date -d "$timestamp" +%Y/%m/%d)/*; do
  timestamp_formatted="$(date -d "$timestamp" +%Y-%m-%d) $(basename "$folder" | sed -r 's/^([0-9]{2})_([0-9]{2})_([0-9]{2})_@[^_]+_(.+)$/\1\\:\2\\:\3\4/')"
  #echo -n '' | ffmpeg -loglevel panic \ # tricking it to not read from terminal, see https://unix.stackexchange.com/questions/600386/zsh-why-do-i-get-suspended-background-processes-even-when-i-have-stty-tostop
  ffmpeg -nostdin -loglevel panic \
    -i "$folder/vid.avi" \
    -i "$folder/screenshot.jpg" \
    -filter_complex "[1:v]scale=320:240 [ovrl], [ovrl] format=yuva444p,colorchannelmixer=aa=0.8 [ovrltr], [0:v][ovrltr] overlay=x=10:y=(H-h-10):alpha=0.5:enable='between(t,0,20)', drawtext=text='$timestamp_formatted':x=10:y=10:fontsize=32:fontcolor=white:bordercolor=black:alpha=0.5" \
    -c:a copy -y "$tmpdir/$(basename "$folder").mp4" &> /dev/null &
  pids+=( $! )
done
wait "${pids[@]}"
mpv --quiet --fs "$tmpdir"
rm -vr "$tmpdir"
