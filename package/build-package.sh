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
# Mixed-ABI: o extrator roda NATIVO no userspace AArch64 do host.
NXEXTRACT_UI_SOURCE="$NXEXTRACT_ROOT/ui/release/aarch64/nxextract-ui"
NXEXTRACT_LICENSE_SOURCE="$NXEXTRACT_ROOT/LICENSE"
PACKAGE_RUNTIME="$PORT_DIR/.build/package-runtime"
LAUNCHER_PATH="$PORT_DIR/Titan Souls.sh"
MATERIALIZED_LAUNCHER=0
NXRELEASE_VERSION=0.2.27
NXRELEASE_SHA256=f303ddb32c5bff7bffab32b7c126627fec61ebbca883abac3942ff864f407bb4
NXGENERATOR_VERSION=0.2.11
NXGENERATOR_SHA256=2f9a8af68249d27abffac810f30d77965af8cea75c52f20d1c1bac21185b96c2
NXBOOTSTRAP_VERSION=0.6.27
NXEXTRACT_VERSION=1.2.13
NXEXTRACT_UI_SHA256=7ca901d8515ab9a084be81e05888e1fd03cec80fb03896df6331c1c95698ef56
MANIFEST="$PORT_DIR/nxrelease.json"
DESTINATION=${1:-"$PORT_DIR/.build/release-1.0.8-candidate.1"}
ARCHIVE_NAME=titansouls-1.0.8-candidate.1.zip

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
  bbab81dca58f2b892db293acbba7fe5731667b67876f6812e3e7b9e2253a5c51 \
  "NXGenerator VERSION"
require_pinned_file \
  "$FRAMEWORK_ROOT/nxgenerator/templates/README.md.in" \
  b3ae732a8782bd6765bf195a4748b4c0fd4e8a96a7b578ad6e1ed7061b22c7a0 \
  "NXGenerator README template"
require_pinned_file \
  "$NXBOOTSTRAP_ROOT/VERSION" \
  8759c4fa1e489f72c3df021cd56022d82e805c25d701c752f66fce797514124a \
  "NXBootstrap VERSION"
require_pinned_file \
  "$NXBOOTSTRAP_ROOT/tools/generate-port.py" \
  ee5c461b45715d670aad2836a54317a14101b579a8b6ba069050e5346d401430 \
  "NXBootstrap generator"
require_pinned_file \
  "$NXBOOTSTRAP_ROOT/templates/launcher.sh.in" \
  bcb8dc5cb8637773bd9feae6289ce83229d137232f080646bc7eb7f89de37f47 \
  "NXBootstrap launcher template"
require_pinned_file \
  "$NXCOMPAT_ROOT/capabilities-v1.json" \
  2e68e1f0aa4567387277cb933b577d2ea9ffabd3a4bf1c9e00721374cd003ec7 \
  "NXCompat capability registry"
require_pinned_file \
  "$NXCOMPAT_ROOT/quirk-registry-v1.json" \
  ffce1d43e33a5affcef294ffb9402351e5da96390de596309be0059ccdd522e8 \
  "NXCompat quirk registry"
require_pinned_file \
  "$NXEXTRACT_ROOT/VERSION" \
  c21698334b1e2308b8556ac1d10402342b8d3e837f65fa1c431eb23392824b1d \
  "NXExtract VERSION"
require_pinned_file \
  "$NXEXTRACT_ROOT/nxextract.py" \
  bd9788283f110dfa9cea62848b3fd49fd3293cae4b3854d7e096584df7e6c17f \
  "NXExtract runtime"
require_pinned_file \
  "$NXEXTRACT_ROOT/run-extractor.sh" \
  c931427c7226d22d7e30eee8549b50f0621dca1c9d0336634aca08631f454d7a \
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
  "$GENERATOR_FRAMEWORK/portmaster/schema" \
  "$GENERATOR_FRAMEWORK/portmaster/vendor" \
  "$GENERATOR_FRAMEWORK/nxsplash/src" \
  "$GENERATOR_FRAMEWORK/nxsplash/release/aarch64" \
  "$GENERATOR_FRAMEWORK/nxsplash/release/armv7" \
  "$GENERATOR_FRAMEWORK/nxsplash/release/i386" \
  "$GENERATOR_FRAMEWORK/nxsplash/release/x86_64" \
  "$GENERATOR_NXEXTRACT/ui/release/aarch64" \
  "$GENERATOR_NXEXTRACT/ui/release/armv7" \
  "$GENERATOR_NXEXTRACT/ui/release/i386" \
  "$GENERATOR_NXEXTRACT/ui/release/x86_64" \
  "$GENERATOR_REPOSITORY/ports/titansouls"
install -m 0644 -- "$NXGENERATOR" \
  "$GENERATOR_FRAMEWORK/nxgenerator/nxgenerator.py"
install -m 0644 -- "$FRAMEWORK_ROOT/nxgenerator/VERSION" \
  "$GENERATOR_FRAMEWORK/nxgenerator/VERSION"
install -m 0644 -- "$FRAMEWORK_ROOT/nxgenerator/templates/README.md.in" \
  "$GENERATOR_FRAMEWORK/nxgenerator/templates/README.md.in"
install -m 0644 -- "$FRAMEWORK_ROOT/nxgenerator/templates/INSTALLATION.md.in" \
  "$GENERATOR_FRAMEWORK/nxgenerator/templates/INSTALLATION.md.in"
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
# nxgenerator 0.2.10 validates the PortMaster contract v2, its metadata schema
# and the vendor provenance, so the sandbox needs all three.
install -m 0644 -- "$FRAMEWORK_ROOT/portmaster/contract-v2.json" \
  "$GENERATOR_FRAMEWORK/portmaster/contract-v2.json"
install -m 0644 -- \
  "$FRAMEWORK_ROOT/portmaster/schema/port-json-supported-v1.schema.json" \
  "$GENERATOR_FRAMEWORK/portmaster/schema/port-json-supported-v1.schema.json"
install -m 0644 -- \
  "$FRAMEWORK_ROOT/portmaster/vendor/PortMaster-GUI-8f9ddc4.json" \
  "$GENERATOR_FRAMEWORK/portmaster/vendor/PortMaster-GUI-8f9ddc4.json"
# nxsplash source is hashed by the generator's release-manifest verifier.
install -m 0644 -- "$FRAMEWORK_ROOT/nxsplash/src/nxsplash.c" \
  "$GENERATOR_FRAMEWORK/nxsplash/src/nxsplash.c"
# NXExtract UI: release manifest, C source and the per-arch artifacts.
install -m 0644 -- "$NXEXTRACT_ROOT/ui/release/manifest-v1.json" \
  "$GENERATOR_NXEXTRACT/ui/release/manifest-v1.json"
install -m 0644 -- "$NXEXTRACT_ROOT/ui/nxextract_ui.c" \
  "$GENERATOR_NXEXTRACT/ui/nxextract_ui.c"
for nxui_arch in aarch64 armv7 i386 x86_64; do
  install -m 0755 -- \
    "$NXEXTRACT_ROOT/ui/release/$nxui_arch/nxextract-ui" \
    "$GENERATOR_NXEXTRACT/ui/release/$nxui_arch/nxextract-ui"
done
# nxbootstrap 0.6.18's generate-port validates the nxsplash release manifest and
# the per-arch splash artifact, so the sandboxed generator repository needs them.
install -m 0644 -- "$FRAMEWORK_ROOT/nxsplash/VERSION" \
  "$GENERATOR_FRAMEWORK/nxsplash/VERSION"
install -m 0644 -- "$FRAMEWORK_ROOT/nxsplash/release/manifest-v1.json" \
  "$GENERATOR_FRAMEWORK/nxsplash/release/manifest-v1.json"
for nxsplash_arch in aarch64 armv7 i386 x86_64; do
  install -m 0755 -- \
    "$FRAMEWORK_ROOT/nxsplash/release/$nxsplash_arch/nxsplash-nextos" \
    "$GENERATOR_FRAMEWORK/nxsplash/release/$nxsplash_arch/nxsplash-nextos"
done
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
