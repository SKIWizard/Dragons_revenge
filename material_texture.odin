package main

import rl "vendor:raylib"

MATERIAL_TEXTURE_STEP :: 8

MaterialTexture :: struct {
    pixels: [^]rl.Color,
    width, height: int,
}

load_material_texture :: proc(path: cstring) -> MaterialTexture {
    image := rl.LoadImage(path)
    if !rl.IsImageValid(image) { return {} }
    defer rl.UnloadImage(image)
    return MaterialTexture{
        pixels = rl.LoadImageColors(image),
        width = int(image.width),
        height = int(image.height),
    }
}

unload_material_texture :: proc(texture: ^MaterialTexture) {
    if texture.pixels != nil { rl.UnloadImageColors(texture.pixels) }
    texture^ = {}
}

// The source stays at its original resolution. Sampling every eighth pixel
// shrinks the visual pattern; world-space wrapping repeats it without moving
// when the camera scrolls or individual material cells are destroyed.
material_texture_color :: proc(texture: ^MaterialTexture, x, y, origin_y: int,
                               fallback: rl.Color) -> rl.Color {
    if texture.pixels == nil || texture.width <= 0 || texture.height <= 0 { return fallback }
    tile_width := max(1, texture.width / MATERIAL_TEXTURE_STEP)
    tile_height := max(1, texture.height / MATERIAL_TEXTURE_STEP)
    tx := (((x % tile_width) + tile_width) % tile_width) * MATERIAL_TEXTURE_STEP
    ty := ((((y-origin_y) % tile_height) + tile_height) % tile_height) * MATERIAL_TEXTURE_STEP
    return texture.pixels[ty*texture.width+tx]
}
