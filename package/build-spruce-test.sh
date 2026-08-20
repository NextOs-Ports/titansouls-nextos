#!/usr/bin/env bash
# Assemble and audit the isolated Titan Souls Spruce ARMHF acceptance ZIP.
set -euo pipefail

export LC_ALL=C
export TZ=UTC
export PYTHONDONTWRITEBYTECODE=1
umask 077

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
PORT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd -P)
DESTINATION=${1:?usage: build-spruce-test.sh DESTINATION_DIRECTORY}
BASE_ZIP=${TS_BASE_ZIP:?set TS_BASE_ZIP to the pinned Titan Souls 1.0.7 ZIP}
NEXTOS_SOURCE_ROOT=${NEXTOS_SOURCE_ROOT:?set NEXTOS_SOURCE_ROOT to the pinned NextOS source tree}

TEST_ID=1.0.8-spruce-test.1
ARCHIVE_NAME="titansouls-$TEST_ID.zip"
EXPECTED_BASE_SHA256=a5fb17fc7ac6f23fafaf10f1a19891d36f4da969bc68edd55789fe5321cff248
EXPECTED_GAME_SHA256=6ee5e4c876a44a96dddb1424a964440ed79f5d152b3ec827be532871ba6c23a0
EXPECTED_UI_SHA256=7ca901d8515ab9a084be81e05888e1fd03cec80fb03896df6331c1c95698ef56
EXPECTED_SPLASH_SHA256=88a2b39be45826348375f966af536e976b37eefd18a88c8fcff75f6fd08015d8
SOURCE_DATE_EPOCH=1787184000

GAME_BINARY="$PORT_DIR/build/titansouls-nextos"
NXEXTRACT_UI="$NEXTOS_SOURCE_ROOT/suportando_outros_devices/extrator-universal/ui/release/aarch64/nxextract-ui"
FINAL_ZIP="$DESTINATION/$ARCHIVE_NAME"
FINAL_SHA="$FINAL_ZIP.sha256"

fail() {
  printf 'spruce test package error: %s\n' "$*" >&2
  exit 1
}

file_sha256() {
  sha256sum -- "$1" | awk '{print $1}'
}

require_hash() {
  local path=$1 expected=$2 label=$3
  [[ -f $path && ! -L $path ]] || fail "$label is missing or unsafe"
  [[ $(file_sha256 "$path") == "$expected" ]] ||
    fail "$label SHA-256 does not match the pinned candidate"
}

[[ -d $DESTINATION && ! -L $DESTINATION ]] ||
  fail "destination is missing or unsafe"
DESTINATION=$(CDPATH= cd -- "$DESTINATION" && pwd -P)
FINAL_ZIP="$DESTINATION/$ARCHIVE_NAME"
FINAL_SHA="$FINAL_ZIP.sha256"
[[ ! -e $FINAL_ZIP && ! -L $FINAL_ZIP ]] ||
  fail "destination archive already exists: $FINAL_ZIP"
[[ ! -e $FINAL_SHA && ! -L $FINAL_SHA ]] ||
  fail "destination checksum already exists: $FINAL_SHA"

require_hash "$BASE_ZIP" "$EXPECTED_BASE_SHA256" "base 1.0.7 ZIP"
require_hash "$GAME_BINARY" "$EXPECTED_GAME_SHA256" "ARMHF game executable"
require_hash "$NXEXTRACT_UI" "$EXPECTED_UI_SHA256" "canonical AArch64 NXExtract UI"

for source_file in \
  "Titan Souls.sh" port-env.sh port.json INSTALLATION.md SPRUCE-TEST.md \
  BUILD-PROVENANCE-SPRUCE-TEST.txt CHANGELOG.md version.txt; do
  [[ -f $PORT_DIR/$source_file && ! -L $PORT_DIR/$source_file ]] ||
    fail "source overlay is missing or unsafe: $source_file"
done

WORK_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/titansouls-spruce-test.XXXXXX")
cleanup() {
  case $WORK_ROOT in
    "${TMPDIR:-/tmp}"/titansouls-spruce-test.*)
      [[ -d $WORK_ROOT ]] && rm -rf -- "$WORK_ROOT"
      ;;
    *) printf 'refusing unsafe cleanup target: %s\n' "$WORK_ROOT" >&2 ;;
  esac
}
trap cleanup EXIT INT TERM

STAGE="$WORK_ROOT/stage"
AUDIT="$WORK_ROOT/audit"
ARCHIVE_TMP="$WORK_ROOT/$ARCHIVE_NAME"
mkdir -p -- "$STAGE" "$AUDIT"

# The base is pinned, but reject unsafe member paths before unpacking anyway.
python3 -B - "$BASE_ZIP" <<'PY'
import pathlib
import stat
import sys
import zipfile

archive = pathlib.Path(sys.argv[1])
with zipfile.ZipFile(archive) as bundle:
    for member in bundle.infolist():
        path = pathlib.PurePosixPath(member.filename)
        if (path.is_absolute() or "\\" in member.filename or
                ".." in path.parts or not path.parts):
            raise SystemExit("unsafe ZIP member: " + member.filename)
        mode = member.external_attr >> 16
        if stat.S_ISLNK(mode):
            raise SystemExit("symlink member is forbidden: " + member.filename)
PY
unzip -q -- "$BASE_ZIP" -d "$STAGE"
[[ -f $STAGE/Titan\ Souls.sh && -d $STAGE/titansouls ]] ||
  fail "base ZIP layout is invalid"
[[ ! -L $STAGE/titansouls ]] || fail "base port directory is a symlink"

# Stale public-release attestations describe 1.0.7 and must never be carried
# into this intentionally private, mixed-ABI test package.
STALE_NXRELEASE="$STAGE/titansouls/.nxrelease"
case $STALE_NXRELEASE in
  "$WORK_ROOT"/stage/titansouls/.nxrelease)
    [[ ! -e $STALE_NXRELEASE || -d $STALE_NXRELEASE ]] ||
      fail "unexpected .nxrelease object"
    [[ ! -e $STALE_NXRELEASE ]] || rm -rf -- "$STALE_NXRELEASE"
    ;;
  *) fail "unsafe stale-attestation target" ;;
esac

install -m 0755 -- "$PORT_DIR/Titan Souls.sh" "$STAGE/Titan Souls.sh"
install -m 0755 -- "$GAME_BINARY" "$STAGE/titansouls/titansouls-nextos"
install -m 0755 -- "$PORT_DIR/port-env.sh" "$STAGE/titansouls/port-env.sh"
install -m 0755 -- "$NXEXTRACT_UI" "$STAGE/titansouls/nxextract/nxextract-ui"
install -m 0644 -- "$PORT_DIR/port.json" "$STAGE/titansouls/port.json"
install -m 0644 -- "$PORT_DIR/INSTALLATION.md" "$STAGE/titansouls/INSTALLATION.md"
install -m 0644 -- "$PORT_DIR/SPRUCE-TEST.md" "$STAGE/titansouls/SPRUCE-TEST.md"
install -m 0644 -- "$PORT_DIR/CHANGELOG.md" "$STAGE/titansouls/CHANGELOG.md"
install -m 0644 -- "$PORT_DIR/version.txt" "$STAGE/titansouls/version.txt"
install -m 0644 -- "$PORT_DIR/BUILD-PROVENANCE-SPRUCE-TEST.txt" \
  "$STAGE/titansouls/BUILD-PROVENANCE.txt"

require_hash "$STAGE/titansouls/nxsplash-nextos" \
  "$EXPECTED_SPLASH_SHA256" "canonical ARMHF NXSplash from the base ZIP"
[[ ! -e $STAGE/titansouls/.nxrelease ]] ||
  fail "stale public-release attestations remain"
[[ -f $STAGE/titansouls/INSTALLATION.md ]] ||
  fail "INSTALLATION.md is absent from the required path"
[[ -f $STAGE/titansouls/SPRUCE-TEST.md ]] ||
  fail "SPRUCE-TEST.md is absent"
[[ ! -e $STAGE/titansouls/TEST-MANIFEST.sha256 ]] ||
  fail "unexpected pre-existing test manifest"
[[ -z $(find "$STAGE" -type l -print -quit) ]] ||
  fail "symlinks are forbidden in the test package"

# Hash every shipped file, including INSTALLATION.md and the root launcher.
(
  cd "$STAGE"
  while IFS= read -r shipped_file; do
    sha256sum -- "$shipped_file"
  done < <(find . -type f ! -path './titansouls/TEST-MANIFEST.sha256' \
    -print | sort)
) > "$STAGE/titansouls/TEST-MANIFEST.sha256"
chmod 0644 "$STAGE/titansouls/TEST-MANIFEST.sha256"

# Fixed timestamps and sorted members make rebuilds of this exact candidate
# byte-identical without embedding a self-referential ZIP hash.
find "$STAGE" -exec touch -h -d "@$SOURCE_DATE_EPOCH" -- {} +
(
  cd "$STAGE"
  find . -mindepth 1 -printf '%P\n' | sort | \
    zip -X -q -9 "$ARCHIVE_TMP" -@
)
unzip -tqq "$ARCHIVE_TMP" || fail "final ZIP integrity test failed"
unzip -q -- "$ARCHIVE_TMP" -d "$AUDIT"

# Audit the ZIP after unpacking, never merely the staging directory.
(
  cd "$AUDIT"
  sha256sum -c titansouls/TEST-MANIFEST.sha256 >/dev/null
) || fail "unpacked test manifest verification failed"
bash -n "$AUDIT/Titan Souls.sh" || fail "launcher syntax check failed"
bash -n "$AUDIT/titansouls/port-env.sh" || fail "port-env syntax check failed"
python3 -B - "$AUDIT/titansouls/port.json" \
  "$AUDIT/titansouls/nxport.json" "$AUDIT/titansouls/extractor.json" <<'PY'
import json
import sys
for path in sys.argv[1:]:
    with open(path, "r", encoding="utf-8") as stream:
        json.load(stream)
PY
python3 -B - "$AUDIT/titansouls/nxextract/nxextract.py" <<'PY'
import ast
import pathlib
import sys
ast.parse(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
PY

[[ $(file_sha256 "$AUDIT/titansouls/titansouls-nextos") == "$EXPECTED_GAME_SHA256" ]] ||
  fail "unpacked game executable hash changed"
[[ $(file_sha256 "$AUDIT/titansouls/nxextract/nxextract-ui") == "$EXPECTED_UI_SHA256" ]] ||
  fail "unpacked NXExtract UI hash changed"
[[ $(file_sha256 "$AUDIT/titansouls/nxsplash-nextos") == "$EXPECTED_SPLASH_SHA256" ]] ||
  fail "unpacked NXSplash hash changed"
file "$AUDIT/titansouls/titansouls-nextos" | grep -q 'ELF 32-bit.*ARM' ||
  fail "game executable is not ARMHF"
file "$AUDIT/titansouls/nxsplash-nextos" | grep -q 'ELF 32-bit.*ARM' ||
  fail "NXSplash is not ARMHF"
file "$AUDIT/titansouls/nxextract/nxextract-ui" | grep -q 'ELF 64-bit.*ARM aarch64' ||
  fail "NXExtract UI is not AArch64"

# Every Linux ELF built or selected by this package must remain at GLIBC 2.30
# or lower. Android owner data is intentionally absent from this ZIP.
while IFS= read -r candidate; do
  readelf -h "$candidate" >/dev/null 2>&1 || continue
  version_info=$(readelf --version-info "$candidate" 2>/dev/null) ||
    fail "could not audit ELF version requirements: $(basename "$candidate")"
  max_glibc=$(printf '%s\n' "$version_info" | grep -o 'GLIBC_[0-9.]*' | \
    sed 's/^GLIBC_//' | sort -Vu | tail -n 1 || true)
  [[ -n $max_glibc ]] || continue
  highest=$(printf '%s\n%s\n' 2.30 "$max_glibc" | sort -Vu | tail -n 1)
  [[ $highest == 2.30 ]] ||
    fail "$(basename "$candidate") requires GLIBC_$max_glibc"
done < <(find "$AUDIT" -type f -print | sort)

# Text files, member names and printable strings from ELFs receive the same
# leak scan. Ripgrep intentionally treats binary input as opaque otherwise.
STRINGS_AUDIT="$WORK_ROOT/package-printable-strings.txt"
(
  find "$AUDIT" -printf '%P\n' | sort
  while IFS= read -r candidate; do
    strings -a -- "$candidate" || exit 1
  done < <(find "$AUDIT" -type f -print | sort)
) > "$STRINGS_AUDIT" || fail "could not extract printable package strings"

# Public-safety gates also apply to this directly shared private artifact.
if find "$AUDIT" -type f \( -name '*.apk' -o -name '*.apkm' -o \
     -name '*.apks' -o -name '*.xapk' -o -name '*.obb' \) -print -quit | \
     grep -q .; then
  fail "owner game data was included"
fi
if find "$AUDIT" -type f \( -iname '*.log' -o -iname 'log.txt' \) \
     -print -quit | grep -q .; then
  fail "raw runtime logs were included"
fi
RG_STATUS=0
rg -n -i 'apkpure|apkmirror|apkvision|5play' \
  "$AUDIT" "$STRINGS_AUDIT" >/dev/null ||
  RG_STATUS=$?
case $RG_STATUS in
  0) fail "an owner-data source name leaked into the package" ;;
  1) ;;
  *) fail "owner-data source-name audit could not run" ;;
esac
RG_STATUS=0
rg -n '/home/felipe|(^|[^0-9])((192[.]168|172[.](1[6-9]|2[0-9]|3[01]))([.][0-9]{1,3}){2}|10([.][0-9]{1,3}){3})([^0-9]|$)' \
  "$AUDIT" "$STRINGS_AUDIT" >/dev/null || RG_STATUS=$?
case $RG_STATUS in
  0) fail "a local path or private test address leaked into the package" ;;
  1) ;;
  *) fail "local-identity audit could not run" ;;
esac
RG_STATUS=0
rg -n '(^|[;&|()])[[:space:]]*(command[[:space:]]+)?stat([[:space:]]|$)' \
  "$AUDIT" --glob '*.sh' >/dev/null || RG_STATUS=$?
case $RG_STATUS in
  0) fail "an executable shell path invokes the external stat command" ;;
  1) ;;
  *) fail "external-stat audit could not run" ;;
esac
rg -q 'NXEXTRACT_REQUIRE_VISIBLE_UI=1' "$AUDIT/Titan Souls.sh" ||
  fail "visible NXExtract is not enforced"
rg -q "renderer=\\(sdl\\|fbdev\\)" "$AUDIT/Titan Souls.sh" ||
  fail "visible NXSplash receipt is not enforced"
rg -q '1d748a7dbe1e97cd8f6fd55dd4b750a19671ec5542ca363f348dd5c8cfa7cde5' \
  "$AUDIT/titansouls/INSTALLATION.md" ||
  fail "reference APK identity is missing from INSTALLATION.md"
GAME_STRINGS="$WORK_ROOT/titansouls-nextos.strings"
strings -a -- "$AUDIT/titansouls/titansouls-nextos" > "$GAME_STRINGS" ||
  fail "could not audit game diagnostic strings"
for diagnostic_token in \
  '[spruce-armhf-test] compiled SDL video drivers=%d' \
  '[spruce-armhf-test] node=%s exists=%d read=%d write=%d' \
  '[spruce-armhf-test] SDL_InitSubSystem(VIDEO)=FAILED error=%s' \
  '[spruce-armhf-test] SDL error after nxgl failure=%s'; do
  rg -Fq "$diagnostic_token" "$GAME_STRINGS" ||
    fail "Spruce diagnostic is missing: $diagnostic_token"
done

ZIP_SHA256=$(file_sha256 "$ARCHIVE_TMP")
SHA_TMP="$WORK_ROOT/$ARCHIVE_NAME.sha256"
printf '%s  %s\n' "$ZIP_SHA256" "$ARCHIVE_NAME" > "$SHA_TMP"
chmod 0644 "$ARCHIVE_TMP"
chmod 0644 "$SHA_TMP"
mv -- "$ARCHIVE_TMP" "$FINAL_ZIP"
mv -- "$SHA_TMP" "$FINAL_SHA"
printf 'created %s\nsha256 %s\n' "$FINAL_ZIP" "$ZIP_SHA256"
