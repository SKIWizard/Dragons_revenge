// Odin's js_wasm32 runtime imports used by this game when linked by Emscripten.
mergeInto(LibraryManager.library, {
  write__deps: ['$UTF8ToString'],
  write: function (fd, pointer, length) {
    var message = UTF8ToString(pointer, length);
    if (fd === 2) console.error(message);
    else console.log(message);
  },
  exp: function (value) { return Math.exp(value); },
  rand_bytes: function (pointer, length) {
    while (length > 0) {
      var count = Math.min(length, 65536);
      crypto.getRandomValues(HEAPU8.subarray(pointer, pointer + count));
      pointer += count;
      length -= count;
    }
  },
});
