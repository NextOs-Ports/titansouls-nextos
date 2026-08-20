#!/usr/bin/env bash
# Titan Souls opens "LOG.txt" itself.  On case-insensitive ROM filesystems that
# aliases nxbootstrap's "log.txt" and unlinks the launch log while it is still
# open.  Move only the game phase to a distinct filename after NXExtract has
# completed, preserving both setup and runtime diagnostics on every firmware.

# Private Spruce/Miyoo Flip ARMHF acceptance candidate.
#
# spruceOS runs an AArch64 userspace but mounts its working ARMHF world below
# /usr/lib32 (and below the firmware-owned fallback roots listed here). The
# inherited 64-bit frontend may also leave a Wayland/KMS SDL video hint in the
# environment. The Flip's 32-bit SDL has one display backend, "mali", so such
# a hint makes SDL_InitSubSystem(VIDEO) fail before nxgl can negotiate a
# window. Clear only that inherited hint and let the 32-bit SDL autodetect;
# never force SDL_VIDEODRIVER. Pin the unversioned EGL/GLES provider because
# the official image maps it directly to the 32-bit libmali, while its
# versioned libEGL.so.1 is a forwarding stub.
case "$(uname -m 2>/dev/null || printf unknown)" in
  aarch64|arm64)
    if [ -d /mnt/SDCARD/spruce/flip ]; then
      TS_SPRUCE_ARMHF_LIBS=""
      TS_SPRUCE_ARMHF_FIRMWARE_FOUND=0
      TS_SPRUCE_ARMHF_HAVE_SDL=0
      TS_SPRUCE_ARMHF_HAVE_EGL=0
      TS_SPRUCE_ARMHF_HAVE_GLES=0
      for ts_spruce_dir in \
        /usr/lib32 /lib32 \
        /mnt/SDCARD/Persistent/.32bit_chroot/usr/lib32 \
        /mnt/SDCARD/Persistent/.32bit_chroot/usr/lib \
        /mnt/SDCARD/Persistent/.32bit_chroot/lib \
        /mnt/SDCARD/spruce/flip/muOS/usr/lib32 \
        /mnt/SDCARD/spruce/flip/muOS/lib32 \
        "${controlfolder:+$controlfolder/libs.armhf}" \
        "${controlfolder:+$controlfolder/libs}"; do
        [ -n "$ts_spruce_dir" ] && [ -d "$ts_spruce_dir" ] || continue
        case ":$TS_SPRUCE_ARMHF_LIBS:" in
          *":$ts_spruce_dir:"*) ;;
          *) TS_SPRUCE_ARMHF_LIBS="${TS_SPRUCE_ARMHF_LIBS:+$TS_SPRUCE_ARMHF_LIBS:}$ts_spruce_dir" ;;
        esac
        TS_SPRUCE_ARMHF_FIRMWARE_FOUND=1
        if [ -e "$ts_spruce_dir/libSDL2-2.0.so.0" ] || \
           [ -e "$ts_spruce_dir/libSDL2.so" ]; then
          TS_SPRUCE_ARMHF_HAVE_SDL=1
        fi
        [ -e "$ts_spruce_dir/libEGL.so" ] && TS_SPRUCE_ARMHF_HAVE_EGL=1
        [ -e "$ts_spruce_dir/libGLESv2.so" ] && TS_SPRUCE_ARMHF_HAVE_GLES=1
      done

      # Game-private directories are useful only after at least one genuine
      # firmware/PortMaster ARMHF runtime root was found; they can never turn a
      # missing 32-bit userspace into a false-positive preflight.
      if [ "$TS_SPRUCE_ARMHF_FIRMWARE_FOUND" = 1 ]; then
        for ts_spruce_dir in "$GAMEDIR/lib" "$GAMEDIR"; do
          [ -n "$ts_spruce_dir" ] && [ -d "$ts_spruce_dir" ] || continue
          case ":$TS_SPRUCE_ARMHF_LIBS:" in
            *":$ts_spruce_dir:"*) ;;
            *) TS_SPRUCE_ARMHF_LIBS="${TS_SPRUCE_ARMHF_LIBS:+$TS_SPRUCE_ARMHF_LIBS:}$ts_spruce_dir" ;;
          esac
        done
      fi

      printf '%s\n' \
        "SPRUCE ARMHF TEST: inherited SDL video hint=${SDL_VIDEODRIVER:-${SDL_VIDEO_DRIVER:-none}}" \
        "SPRUCE ARMHF TEST: clearing the inherited 64-bit SDL backend hint; 32-bit SDL will autodetect" \
        "SPRUCE ARMHF TEST: EGL=libEGL.so GLES=libGLESv2.so runtime=${NXBOOTSTRAP_INTERP_ALT:-/lib/ld-linux-armhf.so.3}"
      unset SDL_VIDEODRIVER SDL_VIDEO_DRIVER SDL_DYNAMIC_API
      export SDL_VIDEO_EGL_DRIVER=libEGL.so
      export SDL_VIDEO_GL_DRIVER=libGLESv2.so
      export TS_SPRUCE_ARMHF_TEST=1

      if [ "$TS_SPRUCE_ARMHF_FIRMWARE_FOUND" = 1 ] && \
         [ "$TS_SPRUCE_ARMHF_HAVE_SDL" = 1 ] && \
         [ "$TS_SPRUCE_ARMHF_HAVE_EGL" = 1 ] && \
         [ "$TS_SPRUCE_ARMHF_HAVE_GLES" = 1 ] && \
         [ -n "$TS_SPRUCE_ARMHF_LIBS" ]; then
        NXBOOTSTRAP_INTERP_LIBS=$TS_SPRUCE_ARMHF_LIBS
        export TS_SPRUCE_ARMHF_LIBRARY_PATH=$TS_SPRUCE_ARMHF_LIBS
        if [ -n "${NXBOOTSTRAP_INTERP_ALT:-}" ]; then
          NXBOOTSTRAP_INTERP_PREFIX="$NXBOOTSTRAP_INTERP_ALT --library-path $NXBOOTSTRAP_INTERP_LIBS"
        else
          # The default ARMHF interpreter exists, so direct exec remains the
          # native flow. Replace inherited AArch64 library hints with the same
          # isolated 32-bit closure; nxbootstrap will prepend its normal
          # firmware roots afterward without losing these fallback mounts.
          export LD_LIBRARY_PATH=$TS_SPRUCE_ARMHF_LIBS
        fi
        printf '%s\n' \
          "SPRUCE ARMHF TEST: isolated 32-bit library path=$TS_SPRUCE_ARMHF_LIBS"
      else
        printf '%s\n' \
          "SPRUCE ARMHF TEST ERROR: incomplete firmware-owned 32-bit graphics closure: roots=$TS_SPRUCE_ARMHF_FIRMWARE_FOUND sdl=$TS_SPRUCE_ARMHF_HAVE_SDL egl=$TS_SPRUCE_ARMHF_HAVE_EGL gles=$TS_SPRUCE_ARMHF_HAVE_GLES"
        exit 68
      fi
      unset TS_SPRUCE_ARMHF_LIBS TS_SPRUCE_ARMHF_FIRMWARE_FOUND \
        TS_SPRUCE_ARMHF_HAVE_SDL TS_SPRUCE_ARMHF_HAVE_EGL \
        TS_SPRUCE_ARMHF_HAVE_GLES ts_spruce_dir
    fi
    ;;
esac

if [ -n "${GAMEDIR:-}" ] && [ -d "$GAMEDIR" ]; then
  [ -s "$GAMEDIR/titansouls-bootstrap.log" ] &&
    mv -f "$GAMEDIR/titansouls-bootstrap.log" \
      "$GAMEDIR/titansouls-bootstrap.prev.log" 2>/dev/null || true
  [ -s "$GAMEDIR/log.txt" ] &&
    mv -f "$GAMEDIR/log.txt" "$GAMEDIR/titansouls-bootstrap.log" \
      2>/dev/null || true
  [ -s "$GAMEDIR/titansouls-runtime.log" ] &&
    mv -f "$GAMEDIR/titansouls-runtime.log" \
      "$GAMEDIR/titansouls-runtime.prev.log" 2>/dev/null || true
  exec >"$GAMEDIR/titansouls-runtime.log" 2>&1
fi
