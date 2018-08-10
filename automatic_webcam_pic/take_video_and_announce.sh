#!/bin/bash
permanent_storage_location="$HOME/automatic_webcam_pics"
latest_screenshot_destination="$HOME/automatic_webcam_pics/latest_screnshot.jpg"
latest_photo_destination="$HOME/automatic_webcam_pics/latest_shot.jpg"
latest_video_destination="$HOME/automatic_webcam_pics/latest_shot.avi"
thumb_max_dimensions="320x180>"
probability_of_shot="100"
delay_in_seconds="0"

workdir="$(mktemp -d "/tmp/.$(basename "$0")_XXXXXXXX")"

destfile_prefix="$permanent_storage_location/$(date  "+%Y/%m/%d/%H_%M_%S_@$(hostname -s)_%:::z")"
lockfile="$HOME/.$(basename "$0")"

function cleanup()
{
  #echo -n
  rm -Rf "$workdir"
}

function update_symlinks()
{
  ln -Tfs "$(date +%Y/%m/%d)" "$permanent_storage_location/today"
  ln -Tfs "$(date  -d "yesterday" "+%Y/%m/%d")" "$permanent_storage_location/yesterday"
}

function capture_screenshot()
{ # {{{
  mkdir -p "$(dirname "$destfile_prefix")"
  cd "$workdir"
  # Two-stage process, quick dump, longer conversion process
  import -window root screenshot.bmp
  convert screenshot.bmp -quality 30 "${destfile_prefix}${manual_infix}_screenshot.jpg"
  cp "${destfile_prefix}${manual_infix}_screenshot.jpg" "$latest_screenshot_destination"
} # }}}
function capture_video()
{ # {{{
  mkdir -p "$(dirname "$destfile_prefix")"

  cd "$workdir"

  # seek somewhat into stream; to get proper colour calibration etc on cam
  ffmpeg -v 0 -f v4l2 -video_size 1280x720 -ss 2 -t 1 -i /dev/video0 video.avi
  mpv --quiet --ao null --vo image video.avi &>/dev/null

  cp video.avi "${destfile_prefix}${manual_infix}.avi"
  cp 00000006.jpg "${destfile_prefix}${manual_infix}.jpg"


  cp video.avi "$latest_video_destination"
  echo "${destfile_prefix}${manual_infix}.jpg"

  cd &> /dev/null
} # }}}

function announce_about_just_taken_photo()
{ # {{{
  local summary="$1"
  local body="$2"
  local photo_path="$3"

  local workdir="$(mktemp -d "/tmp/.$(basename "$0")_XXXXXXXX")"
  # flop to mirror it for reverse display (which seems more natural, after all?)
  convert -flop -resize "$thumb_max_dimensions" "$photo_path"  "$workdir/thumbnail.jpg"

  notify-send -t 4000 -i "$workdir/thumbnail.jpg" "$summary" "$body"
  #notify-send -t 4000 "$summary" "$body"
  rm -Rf "$workdir"
} # }}}



manual_infix=""
while [ "0" != "$#" ]; do
  case "$1" in
    --probability-of-shot)
      probability_of_shot="$2"
      shift ;;
    --manual)
      manual_infix="_manual"
      ;;
    --capture-screenshot)
      capture_screenshot="set"
      ;;
    --block)
      block="set"
      ;;
    --random-delay-up-to)
      delay_in_seconds="$((RANDOM%$2))"
      shift ;;
    *)
      echo "Unrecognized option: \"$1\". Aborting hard." >&2
      exit 1 ;;
  esac
  shift
done

if [ -n "$block" ]; then
  lockfile-create "$lockfile"
  lockfile-touch "$lockfile" & lockfile_touch_pid="$!"
  trap "kill $lockfile_touch_pid; lockfile-remove ${VERBOSEMODE:+--verbose} $lockfile" EXIT
  for ((i=10;i>0;i--)); do
    notify-send -t 60000  "Automatic webcam shots blocked" "$i min left"
    sleep 60
  done
  notify-send -u critical -t 10000  "Automatic webcam shots unblocked"
  exit $?
fi



if (( RANDOM%100 > probability_of_shot )); then
  cleanup
  exit 0
fi

sleep $delay_in_seconds

lockfile-create "$lockfile" || exit 0
lockfile-touch "$lockfile" & lockfile_touch_pid="$!"
trap "kill $lockfile_touch_pid; lockfile-remove ${VERBOSEMODE:+--verbose} $lockfile" EXIT

if [ -n "$capture_screenshot" ]; then
  capture_screenshot & pid="$!"
fi
#announce_about_picture_about_to_be_taken
snapshot_in="$(capture_video)"

[ -z "$pid" ] || wait "$pid"

if [ -n "$capture_screenshot" ]; then
  announce_about_just_taken_photo "Video'ed & screenshotted" "" "$snapshot_in"
else
  announce_about_just_taken_photo "Video'ed" "" "$snapshot_in"
fi

update_symlinks
cleanup

# vim: fml=1 fdm=marker
