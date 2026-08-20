#include "spruce_armhf_diag.h"

#include <SDL.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

extern int __real_SDL_InitSubSystem(Uint32 flags);

static int ts_spruce_diag_enabled(void) {
  const char *value = getenv("TS_SPRUCE_ARMHF_TEST");
  return value && strcmp(value, "1") == 0;
}

void ts_spruce_armhf_diag_pre_video(void) {
  static const char *const device_nodes[] = {
      "/dev/fb0", "/dev/ion", "/dev/mali0", "/dev/dri/card0",
      "/dev/dri/renderD128",
  };
  int driver_count;
  size_t index;

  if (!ts_spruce_diag_enabled())
    return;

  fprintf(stderr,
          "[spruce-armhf-test] egl=%s gles=%s video_hint=%s\n",
          getenv("SDL_VIDEO_EGL_DRIVER")
              ? getenv("SDL_VIDEO_EGL_DRIVER")
              : "(auto)",
          getenv("SDL_VIDEO_GL_DRIVER") ? getenv("SDL_VIDEO_GL_DRIVER")
                                         : "(auto)",
          getenv("SDL_VIDEODRIVER") ? getenv("SDL_VIDEODRIVER") : "(auto)");

  driver_count = SDL_GetNumVideoDrivers();
  fprintf(stderr, "[spruce-armhf-test] compiled SDL video drivers=%d", driver_count);
  for (int driver = 0; driver < driver_count; ++driver) {
    const char *name = SDL_GetVideoDriver(driver);
    fprintf(stderr, "%s%s", driver == 0 ? " [" : ",", name ? name : "?");
  }
  fprintf(stderr, "%s\n", driver_count > 0 ? "]" : "");

  for (index = 0; index < sizeof(device_nodes) / sizeof(device_nodes[0]); ++index) {
    const char *node = device_nodes[index];
    fprintf(stderr,
            "[spruce-armhf-test] node=%s exists=%d read=%d write=%d\n",
            node, access(node, F_OK) == 0, access(node, R_OK) == 0,
            access(node, W_OK) == 0);
  }
}

int __wrap_SDL_InitSubSystem(Uint32 flags) {
  int status = __real_SDL_InitSubSystem(flags);

  if (ts_spruce_diag_enabled() && (flags & SDL_INIT_VIDEO) != 0) {
    if (status == 0) {
      fprintf(stderr,
              "[spruce-armhf-test] SDL_InitSubSystem(VIDEO)=OK driver=%s\n",
              SDL_GetCurrentVideoDriver() ? SDL_GetCurrentVideoDriver() : "?");
    } else {
      const char *error = SDL_GetError();
      fprintf(stderr,
              "[spruce-armhf-test] SDL_InitSubSystem(VIDEO)=FAILED error=%s\n",
              error && *error ? error : "(SDL returned no detail)");
    }
  }
  return status;
}
