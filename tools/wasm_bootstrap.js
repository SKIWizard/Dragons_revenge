// Odin's program entrypoint is _start; Emscripten's shell otherwise waits for C main.
Module['onRuntimeInitialized'] = function () {
  Module['__start']();
};
