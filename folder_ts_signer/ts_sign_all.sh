#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail
trap "echo 'Interrupted. Aborting with error exit status.'; exit 1;" INT
trap "echo \"Error occured in subcommand @ \${BASH_SOURCE[0]}:\$LINENO; exiting\"; exit 1;" ERR

if test ${BASH_VERSINFO[0]} -lt 4; then
  echo "This is a bash 4+ script"
  exit 1
fi

for prog in gpg openssl curl column base64; do
  if ! which "$prog" >& /dev/null; then
    echo "Needs $prog to be in PATH. Aborting." >&2
    exit 1
  fi
done

# Options parsing:
declare -A options=( \
  ['ts-signatures-in:']="$HOME/.ts-signatures" \
)

declare -a folders_to_sign_from=()

while [ "0" != "$#" ]; do
  for key in "${!options[@]}"; do
    if [[ "--${key%%:}" == "$1" ]]; then
      if [[ $key =~ : ]]; then
        options["$key"]="$2"
        shift
      else
        options["$key"]="set"
      fi
      shift
      continue 2
    fi
  done
  # Manual option parsing for non-$options options:
  case "$1" in
    --help)
      echo "Usage: $(basename "$0") [--ts-signatures-in folder] input-folder [input-folder ...]"$'\n'
      echo "Will loop over input folders, and for each file found, detach-sign it and"
      echo "obtain Time Stamping Authories' responses about the signature's existence."$'\n'
      echo $'Some scrappy autodocumentation:\n'
      for keys in "${!options[@]}"; do
        echo "--$key: ${options[$key]##*##}"
      done | column -t
      exit 0
      ;;
    *)
      if [ -d "$1" ]; then
        folders_to_sign_from+=( "$1" )
      else
        echo "Given parameter \"$!\" isn't a folder." >&2
        exit 1
      fi
      ;;
  esac
  shift
done


# Function definitions for the below:

function tsr_with_tsa ()
{
  local tsa="$1"
  local tsq_file="$2"
  case "$tsa" in
    freetsa)
      if [ ! -e "${options['ts-signatures-in:']}/freetsa.tsa.crt" ]; then
        curl -so "${options['ts-signatures-in:']}/freetsa.tsa.crt" "https://freetsa.org/files/tsa.crt"
      fi
      if [ ! -e "${options['ts-signatures-in:']}/freetsa.cacert.pem" ]; then
        curl -so "${options['ts-signatures-in:']}/freetsa.cacert.pem" "https://freetsa.org/files/cacert.pem"
      fi
      curl -sH "Content-Type: application/timestamp-query" --data-binary "@$tsq_file" https://freetsa.org/tsr
      ;;
    *)
      echo "Unrecognized TSA: $tsa; aborting." >&2
      return 1
      ;;
  esac
}

function sign_single_file ()
{
  local tsa="freetsa"
  local relpath="$1"
  local basename_of_file="$(basename "$relpath")"
  local hash_of_file="$(openssl sha256 "$relpath" | awk '{print $NF}')"

  if [ -e "${options['ts-signatures-in:']}/$relpath.$hash_of_file"*.tsr ]; then
    : "File \"$relpath\" already ts-signed." >&2
    return 0
  fi

  # Sign with default gpg signing key:
  gpg --quiet -o "$tmpdir/$basename_of_file.$hash_of_file.sig" --detach-sign "$relpath"

  # Form the time stamping query:
  openssl ts -query -data "$file" -sha512 > "$tmpdir/$basename_of_file.$hash_of_file.sig.tsq" 2> >(grep -v "^Using configuration from" >&2)

  # Shoot it off to all TSA's (currently, only freetsa):
  for tsa in "freetsa"; do
    tsr_with_tsa "$tsa" "$tmpdir/$basename_of_file.$hash_of_file.sig.tsq" > "$tmpdir/$basename_of_file.$hash_of_file.sig.$tsa.tsr"

    # Assert (through errexit) that the tsr verifies before proceeding with it.
    # (Also, this is how you'd verify a TSR.)
    openssl ts -verify \
      -in "$tmpdir/$basename_of_file.$hash_of_file.sig.$tsa.tsr" \
      -queryfile "$tmpdir/$basename_of_file.$hash_of_file.sig.tsq" \
      -CAfile "${options['ts-signatures-in:']}/$tsa.cacert.pem" \
      -untrusted "${options['ts-signatures-in:']}/$tsa.tsa.crt" &> >(egrep -v "^(Using configuration from|Verification: OK)")
  done

  mkdir -p "${options['ts-signatures-in:']}/$(dirname "$relpath")"
  mv \
    "$tmpdir/$basename_of_file.$hash_of_file.sig" \
    "$tmpdir/$basename_of_file.$hash_of_file.sig.tsq" \
    "$tmpdir/$basename_of_file.$hash_of_file.sig."*".tsr" \
    "${options['ts-signatures-in:']}/$(dirname "$relpath")/"
  echo "Signed & ts-signed $relpath"
}

if [ ! -d "${options['ts-signatures-in:']}" ]; then
  echo "Non-directory --ts-signatures-in given; erring out." &>2
  exit 1
fi

# The action itself:

tmpdir="$(mktemp -d /tmp/$(basename "$0")_XXXXX)"
trap "rm -R '$tmpdir';" EXIT
for signing_dir in "${folders_to_sign_from[@]}"; do
  find "$signing_dir" -type f | while read file; do
    sign_single_file "$file"
  done
done
