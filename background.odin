package main

import rl "vendor:raylib"

BACKGROUND_DIM_ALPHA :: 110

// Scroll the wide image more slowly than foreground cells, using the camera's
// fractional position. Source cropping keeps the background continuous.
background_source_x :: proc(texture_width, texture_height: int, camera_x: f32) -> f32 {
    view_width := f32(VIEW_W*CELL_SIZE)
    view_height := f32(VIEW_H*CELL_SIZE)
    source_width := view_width*f32(texture_height)/view_height
    if source_width >= f32(texture_width) { return 0 }
    fraction := camera_x/f32(WORLD_W-VIEW_W)
    if fraction < 0 { fraction = 0 }
    if fraction > 1 { fraction = 1 }
    return (f32(texture_width)-source_width)*fraction
}

draw_background :: proc(texture: rl.Texture2D, camera_x: f32) {
    if !rl.IsTextureValid(texture) { return }
    view_width := f32(VIEW_W*CELL_SIZE)
    view_height := f32(VIEW_H*CELL_SIZE)
    source_width := view_width*f32(texture.height)/view_height
    if source_width > f32(texture.width) { source_width = f32(texture.width) }
    source := rl.Rectangle{background_source_x(int(texture.width), int(texture.height), camera_x), 0, source_width, f32(texture.height)}
    destination := rl.Rectangle{0, 0, view_width, view_height}
    rl.DrawTexturePro(texture, source, destination, rl.Vector2{}, 0, rl.WHITE)
    rl.DrawRectangle(0, 0, VIEW_W*CELL_SIZE, VIEW_H*CELL_SIZE, rl.Color{10, 16, 28, BACKGROUND_DIM_ALPHA})
}
