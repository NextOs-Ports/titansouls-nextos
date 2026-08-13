#!/usr/bin/env bash
# Build and atomically bundle the data-free Titan Souls release candidate.
set -euo pipefail

export LC_ALL=C
export TZ=UTC
export PYTHONDONTWRITEBYTECODE=1
umask 077

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
PORT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd -P)
REPOSITORY_ROOT=$(git -C "$PORT_DIR" rev-parse --show-toplevel)
FRAMEWORK_ROOT=${NEXTOS_FRAMEWORK_ROOT:-}
if [[ -z $FRAMEWORK_ROOT && -d $REPOSITORY_ROOT/framework ]]; then
  FRAMEWORK_ROOT=$REPOSITORY_ROOT/framework
fi
[[ -n $FRAMEWORK_ROOT && -d $FRAMEWORK_ROOT ]] || {
  printf '%s\n' \
    'set NEXTOS_FRAMEWORK_ROOT to the external NextOS framework source tree' >&2
  exit 1
}
FRAMEWORK_ROOT=$(CDPATH= cd -- "$FRAMEWORK_ROOT" && pwd -P)

NXEXTRACT_ROOT=${NXEXTRACT_SOURCE_ROOT:-}
if [[ -z $NXEXTRACT_ROOT &&
      -d $REPOSITORY_ROOT/suportando_outros_devices/extrator-universal ]]; then
  NXEXTRACT_ROOT=$REPOSITORY_ROOT/suportando_outros_devices/extrator-universal
fi
[[ -n $NXEXTRACT_ROOT && -d $NXEXTRACT_ROOT ]] || {
  printf '%s\n' \
    'set NXEXTRACT_SOURCE_ROOT to the external canonical NXExtract source tree' >&2
  exit 1
}
NXEXTRACT_ROOT=$(CDPATH= cd -- "$NXEXTRACT_ROOT" && pwd -P)

NXRELEASE="$FRAMEWORK_ROOT/nxrelease/nxrelease.py"
NXGENERATOR="$FRAMEWORK_ROOT/nxgenerator/nxgenerator.py"
NXABI="$FRAMEWORK_ROOT/nxabi/nxabi.py"
NXBOOTSTRAP_ROOT="$FRAMEWORK_ROOT/nxbootstrap"
NXCOMPAT_ROOT="$FRAMEWORK_ROOT/nxcompat"
NXEXTRACT_UI_SOURCE="$NXEXTRACT_ROOT/ui/build/nxextract-ui"
NXEXTRACT_LICENSE_SOURCE="$NXEXTRACT_ROOT/LICENSE"
PACKAGE_RUNTIME="$PORT_DIR/.build/package-runtime"
LAUNCHER_PATH="$PORT_DIR/Titan Souls.sh"
MATERIALIZED_LAUNCHER=0
NXRELEASE_VERSION=0.2.5
NXRELEASE_SHA256=097ef954261d7e31fb4a759caf2ebda9be02f069b1968e3f7b379d92f51e732f
NXGENERATOR_VERSION=0.2.0
NXGENERATOR_SHA256=4bcf6de0cce5e854bf66bbcb877cb111ec3184f7193137968fdeb5f33caa1c7e
NXBOOTSTRAP_VERSION=0.6.5
NXEXTRACT_VERSION=1.2.6
NXEXTRACT_UI_SHA256=046afb583f5a211c946495e639409f81d9cfec706788eeccb7924b0e8e5a50b6
MANIFEST="$PORT_DIR/nxrelease.json"
DESTINATION=${1:-"$PORT_DIR/.build/release-1.0.0-rc.4"}
ARCHIVE_NAME=titansouls-1.0.0-rc.4.zip

fail() {
  printf 'titansouls package error: %s\n' "$*" >&2
  exit 1
}

require_pinned_file() {
  local input_path=$1 expected_sha256=$2 label=$3
  [[ -f $input_path && ! -L $input_path ]] ||
    fail "$label is missing or unsafe"
  [[ $(sha256sum -- "$input_path" | awk '{print $1}') == "$expected_sha256" ]] ||
    fail "$label SHA-256 drifted"
}

[[ -f $NXRELEASE && -f $NXGENERATOR && -f $NXABI && -f $MANIFEST ]] ||
  fail "release tool, generator, ABI gate or manifest is missing"
[[ $(sha256sum -- "$NXRELEASE" | awk '{print $1}') == "$NXRELEASE_SHA256" ]] ||
  fail "NXRelease SHA-256 drifted"
[[ $(python3 -B "$NXRELEASE" --version) == "nxrelease $NXRELEASE_VERSION" ]] ||
  fail "NXRelease version drifted"
[[ $(sha256sum -- "$NXGENERATOR" | awk '{print $1}') == "$NXGENERATOR_SHA256" ]] ||
  fail "NXGenerator SHA-256 drifted"
[[ $(cat "$FRAMEWORK_ROOT/nxgenerator/VERSION") == "$NXGENERATOR_VERSION" ]] ||
  fail "NXGenerator version drifted"
[[ $(cat "$NXBOOTSTRAP_ROOT/VERSION") == "$NXBOOTSTRAP_VERSION" ]] ||
  fail "NXBootstrap version drifted"
[[ $(cat "$NXEXTRACT_ROOT/VERSION") == "$NXEXTRACT_VERSION" ]] ||
  fail "NXExtract version drifted"
require_pinned_file \
  "$FRAMEWORK_ROOT/nxgenerator/VERSION" \
  1f930dd1f133c1f97a94fe3acb8db34372cf4c01ffdb2b3ff4ca72f9494121e9 \
  "NXGenerator VERSION"
require_pinned_file \
  "$FRAMEWORK_ROOT/nxgenerator/templates/README.md.in" \
  98fc7eff000bef589b69e5b6f57dd437b95dc7f8f15c7280c622ca1533479a83 \
  "NXGenerator README template"
require_pinned_file \
  "$NXBOOTSTRAP_ROOT/VERSION" \
  34bf52562bae401de106933a7565c9d3a5c8dc83c04b0b29492dd3f6f3983b7a \
  "NXBootstrap VERSION"
require_pinned_file \
  "$NXBOOTSTRAP_ROOT/tools/generate-port.py" \
  571cbc2e8dfcc60ae49a5ba2aa85db4e94a1938fbb683da4196117bb3d329850 \
  "NXBootstrap generator"
require_pinned_file \
  "$NXBOOTSTRAP_ROOT/templates/launcher.sh.in" \
  003d59c43abfd3f85eaf890f9ad718be0956e24b84d610676961a5faad485cbc \
  "NXBootstrap launcher template"
require_pinned_file \
  "$NXCOMPAT_ROOT/capabilities-v1.json" \
  0f302c49572c34e57448342cf0ecf605c96c9af2b02d5a2adccfa5dc93d75b4c \
  "NXCompat capability registry"
require_pinned_file \
  "$NXCOMPAT_ROOT/quirk-registry-v1.json" \
  f5d597e884c6c70b6234dceef8bdad690f20ae07c7548ebdd45660d2b16de1b1 \
  "NXCompat quirk registry"
require_pinned_file \
  "$NXEXTRACT_ROOT/VERSION" \
  5844ffcc346f89c07b13ba7596bfb3788ed73f4755e541182d7822d43b7c7a24 \
  "NXExtract VERSION"
require_pinned_file \
  "$NXEXTRACT_ROOT/nxextract.py" \
  a4a8e5d3bf2a1344491e27921c54430ee9b4e3fedd0160631da96734fa3d5170 \
  "NXExtract runtime"
require_pinned_file \
  "$NXEXTRACT_ROOT/run-extractor.sh" \
  179b72f02b9dfdf3ed1bdc382d074fb4ef07f83e3d62cfccfc74a950e68679c2 \
  "NXExtract runner"
require_pinned_file \
  "$NXEXTRACT_ROOT/nxextract-runtime-env.sh" \
  332919a9960d4317563b647f9932d1a4367da147a425fe2f78eafd706f01563f \
  "NXExtract runtime environment"
require_pinned_file \
  "$NXEXTRACT_LICENSE_SOURCE" \
  74d7d9d40e27fbfe23cb462f9608fa07cbe53ffb0b88a0da9e85dda240c2c788 \
  "NXExtract licence"
[[ -f $NXEXTRACT_UI_SOURCE && ! -L $NXEXTRACT_UI_SOURCE &&
   -f $NXEXTRACT_LICENSE_SOURCE && ! -L $NXEXTRACT_LICENSE_SOURCE ]] ||
  fail "canonical NXExtract UI or licence is missing or unsafe"
[[ $(sha256sum -- "$NXEXTRACT_UI_SOURCE" | awk '{print $1}') == "$NXEXTRACT_UI_SHA256" ]] ||
  fail "canonical NXExtract UI SHA-256 drifted"
[[ ! -e $DESTINATION && ! -L $DESTINATION ]] ||
  fail "destination already exists: $DESTINATION"

WORK_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/titansouls-package.XXXXXX")
cleanup() {
  if [[ $MATERIALIZED_LAUNCHER == 1 ]]; then
    if [[ -f $LAUNCHER_PATH && ! -L $LAUNCHER_PATH ]]; then
      rm -f -- "$LAUNCHER_PATH"
    else
      printf 'refusing unsafe generated-launcher cleanup: %s\n' \
        "$LAUNCHER_PATH" >&2
    fi
  fi
  case $WORK_ROOT in
    "${TMPDIR:-/tmp}"/titansouls-package.*)
      [[ -d $WORK_ROOT ]] && rm -rf -- "$WORK_ROOT"
      ;;
    *) printf 'refusing unsafe cleanup target: %s\n' "$WORK_ROOT" >&2 ;;
  esac
}
trap cleanup EXIT INT TERM

GENERATOR_REPOSITORY="$WORK_ROOT/generator-repository"
GENERATOR_FRAMEWORK="$GENERATOR_REPOSITORY/framework"
GENERATOR_NXEXTRACT="$GENERATOR_REPOSITORY/suportando_outros_devices/extrator-universal"
mkdir -p -- \
  "$GENERATOR_FRAMEWORK/nxgenerator/templates" \
  "$GENERATOR_FRAMEWORK/nxbootstrap/tools" \
  "$GENERATOR_FRAMEWORK/nxbootstrap/templates" \
  "$GENERATOR_FRAMEWORK/nxcompat" \
  "$GENERATOR_NXEXTRACT" \
  "$GENERATOR_REPOSITORY/ports/titansouls"
install -m 0644 -- "$NXGENERATOR" \
  "$GENERATOR_FRAMEWORK/nxgenerator/nxgenerator.py"
install -m 0644 -- "$FRAMEWORK_ROOT/nxgenerator/VERSION" \
  "$GENERATOR_FRAMEWORK/nxgenerator/VERSION"
install -m 0644 -- "$FRAMEWORK_ROOT/nxgenerator/templates/README.md.in" \
  "$GENERATOR_FRAMEWORK/nxgenerator/templates/README.md.in"
install -m 0644 -- "$NXBOOTSTRAP_ROOT/VERSION" \
  "$GENERATOR_FRAMEWORK/nxbootstrap/VERSION"
install -m 0644 -- "$NXBOOTSTRAP_ROOT/tools/generate-port.py" \
  "$GENERATOR_FRAMEWORK/nxbootstrap/tools/generate-port.py"
install -m 0644 -- "$NXBOOTSTRAP_ROOT/templates/launcher.sh.in" \
  "$GENERATOR_FRAMEWORK/nxbootstrap/templates/launcher.sh.in"
install -m 0644 -- "$NXCOMPAT_ROOT/capabilities-v1.json" \
  "$GENERATOR_FRAMEWORK/nxcompat/capabilities-v1.json"
install -m 0644 -- "$NXCOMPAT_ROOT/quirk-registry-v1.json" \
  "$GENERATOR_FRAMEWORK/nxcompat/quirk-registry-v1.json"
install -m 0644 -- "$NXEXTRACT_ROOT/VERSION" \
  "$GENERATOR_NXEXTRACT/VERSION"
install -m 0644 -- "$NXEXTRACT_LICENSE_SOURCE" \
  "$GENERATOR_NXEXTRACT/LICENSE"
for runtime_file in nxextract.py run-extractor.sh nxextract-runtime-env.sh; do
  install -m 0644 -- "$NXEXTRACT_ROOT/$runtime_file" \
    "$GENERATOR_NXEXTRACT/$runtime_file"
done
install -m 0644 -- "$PORT_DIR/LICENSE" "$GENERATOR_REPOSITORY/LICENSE"
install -m 0644 -- "$PORT_DIR/extractor.json" \
  "$GENERATOR_REPOSITORY/ports/titansouls/extractor.json"

python3 -B "$GENERATOR_FRAMEWORK/nxgenerator/nxgenerator.py" \
  "$PORT_DIR/nxproject.json" \
  --output "$WORK_ROOT/generated" >/dev/null
if [[ -e $LAUNCHER_PATH || -L $LAUNCHER_PATH ]]; then
  [[ -f $LAUNCHER_PATH && ! -L $LAUNCHER_PATH ]] ||
    fail "public launcher is not a safe regular file"
  cmp -s "$LAUNCHER_PATH" "$WORK_ROOT/generated/Titan Souls.sh" ||
    fail "public launcher differs from nxgenerator output"
else
  install -m 0755 -- "$WORK_ROOT/generated/Titan Souls.sh" "$LAUNCHER_PATH"
  MATERIALIZED_LAUNCHER=1
fi
for relative in LICENSE extractor.json nxport.json nxproject.json; do
  cmp -s "$PORT_DIR/$relative" "$WORK_ROOT/generated/titansouls/$relative" ||
    fail "generated deployment drifted: $relative"
done

mkdir -p -- "$PACKAGE_RUNTIME/nxextract" "$PACKAGE_RUNTIME/licenses"
for runtime_file in nxextract.py run-extractor.sh nxextract-runtime-env.sh; do
  install -m 0644 -- \
    "$WORK_ROOT/generated/titansouls/nxextract/$runtime_file" \
    "$PACKAGE_RUNTIME/nxextract/$runtime_file"
done
install -m 0755 -- "$NXEXTRACT_UI_SOURCE" \
  "$PACKAGE_RUNTIME/nxextract/nxextract-ui"
install -m 0644 -- "$NXEXTRACT_LICENSE_SOURCE" \
  "$PACKAGE_RUNTIME/licenses/NXExtract-MIT.txt"

python3 -B "$PACKAGE_RUNTIME/nxextract/nxextract.py" recipe-check \
  --recipe "$PORT_DIR/extractor.json"

if [[ ${TS_SKIP_BUILD:-0} != 1 ]]; then
  "$PORT_DIR/build_universal.sh"
fi
[[ -f $PORT_DIR/build/titansouls-nextos &&
   ! -L $PORT_DIR/build/titansouls-nextos ]] ||
  fail "final executable is missing or unsafe"
python3 -B "$NXABI" audit --errors-only \
  "$PORT_DIR/build/titansouls-nextos" \
  "$PACKAGE_RUNTIME/nxextract/nxextract-ui"
python3 -B "$NXRELEASE" validate --manifest "$MANIFEST" --max-glibc 2.30

mkdir -p -- "$(dirname -- "$DESTINATION")"
python3 -B "$NXRELEASE" bundle \
  --manifest "$MANIFEST" --stage "$WORK_ROOT/stage" \
  --destination "$DESTINATION" --archive-name "$ARCHIVE_NAME" \
  --max-glibc 2.30
python3 -B "$NXRELEASE" verify \
  --archive "$DESTINATION/$ARCHIVE_NAME" \
  --sha256-file "$DESTINATION/$ARCHIVE_NAME.sha256" --max-glibc 2.30

if unzip -Z1 "$DESTINATION/$ARCHIVE_NAME" |
    grep -E '(^|/)(run[.]sh|[^/]+[.](apk|apkm|apks|xapk|obb|so|log|raw|sav))$'; then
  fail "public ZIP contains a forbidden secondary launcher or owner/runtime data"
fi

printf 'Titan Souls data-free release candidate: %s\n' \
  "$DESTINATION/$ARCHIVE_NAME"
printf '%s\n' \
  'proprietary_payload=0 universal_release_ready=0 predecessor_quick_boot=two-families rocknix_audio_tester_report=passed final_zip_physical_test=pending mali_450_tile_grid=known_limitation'
sha256sum -- "$DESTINATION/$ARCHIVE_NAME"
