"""Build the browser edition with Odin, Emscripten and the bundled raylib archive."""

from pathlib import Path
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "wasm"


def main() -> None:
    odin = shutil.which("odin")
    emcc = shutil.which("emcc")
    if not odin or not emcc:
        raise SystemExit("Install Odin and Emscripten (emcc) before building WASM")

    odin_root = Path(subprocess.check_output([odin, "root"], text=True).strip())
    raylib = odin_root / "vendor/raylib/wasm/libraylib.a"
    if not raylib.is_file():
        raise SystemExit(f"Missing Odin raylib web archive: {raylib}")

    OUTPUT.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="dragons-wasm-") as temporary:
        source = Path(temporary) / "source"
        source.mkdir()
        for file in ROOT.glob("*.odin"):
            if not file.name.endswith("_test.odin"):
                shutil.copy2(file, source / file.name)
        obj = Path(temporary) / "game.o"
        subprocess.run(
            [odin, "build", str(source), "-target:js_wasm32", "-build-mode:obj",
             "-define:RAYLIB_WASM_LIB=env.o", f"-out:{obj}"],
            cwd=ROOT, check=True,
        )
        command = [
            emcc, str(obj), str(raylib), "-o", str(OUTPUT / "index.html"),
            "-sUSE_GLFW=3", "-sASYNCIFY=1", "-sASYNCIFY_STACK_SIZE=8388608",
            "-sALLOW_MEMORY_GROWTH=1",
            "-sINITIAL_MEMORY=268435456", "-sSTACK_SIZE=16777216",
            "-sFORCE_FILESYSTEM=1",
            "-sEXPORTED_RUNTIME_METHODS=HEAPF32",
            "--shell-file", str(ROOT / "tools/wasm_shell.html"),
            "--pre-js", str(ROOT / "tools/wasm_bootstrap.js"),
            "--js-library", str(ROOT / "tools/odin_wasm_library.js"),
            "--preload-file", "assets@/assets",
            "--preload-file", "DinoSprites - vita.png@/DinoSprites - vita.png",
            "--preload-file", "dragon_icon.png@/dragon_icon.png",
            "--preload-file", "blue_knight_icon.png@/blue_knight_icon.png",
        ]
        subprocess.run(command, cwd=ROOT, check=True)
        # Odin's core:sys/wasm imports live in the odin_env module. Emscripten
        # resolves their function names, but emits only its own env namespace.
        javascript = OUTPUT / "index.js"
        script = javascript.read_text()
        marker = "    'env': wasmImports,"
        if script.count(marker) != 1:
            raise SystemExit("Emscripten import layout changed; update Odin import mapping")
        script = script.replace(marker, marker + "\n    'odin_env': wasmImports,", 1)
        # Odin can grow WebAssembly memory directly; refresh Emscripten's typed
        # array views before the next imported call after such a growth.
        import_marker = "function getWasmImports() {"
        if script.count(import_marker) != 1:
            raise SystemExit("Emscripten import setup changed; update memory view bridge")
        bridge = """function getWasmImports() {
  for (const name of Object.keys(wasmImports)) {
    const original = wasmImports[name];
    const wrapped = function (...args) {
      if (wasmMemory && HEAPU8?.buffer !== wasmMemory.buffer) updateMemoryViews();
      return original(...args);
    };
    Object.assign(wrapped, original);
    wasmImports[name] = wrapped;
  }
"""
        javascript.write_text(script.replace(import_marker, bridge, 1))
    print(f"Browser build: {OUTPUT / 'index.html'}")


if __name__ == "__main__":
    main()
