package main

import rl "vendor:raylib"

CANVAS_W :: VIEW_W*CELL_SIZE
CANVAS_H :: VIEW_H*CELL_SIZE

CanvasViewport :: struct {
    x, y, width, height, scale: f32,
}

canvas_viewport :: proc(screen_width, screen_height: int) -> CanvasViewport {
    width := max(1, screen_width)
    height := max(1, screen_height)
    scale := min(f32(width)/f32(CANVAS_W), f32(height)/f32(CANVAS_H))
    scaled_width := f32(CANVAS_W)*scale
    scaled_height := f32(CANVAS_H)*scale
    return CanvasViewport{
        x = (f32(width)-scaled_width)*0.5,
        y = (f32(height)-scaled_height)*0.5,
        width = scaled_width,
        height = scaled_height,
        scale = scale,
    }
}

canvas_mouse :: proc(mouse: rl.Vector2, viewport: CanvasViewport) -> (rl.Vector2, bool) {
    inside := mouse.x >= viewport.x && mouse.x < viewport.x+viewport.width &&
              mouse.y >= viewport.y && mouse.y < viewport.y+viewport.height
    return rl.Vector2{(mouse.x-viewport.x)/viewport.scale,
                      (mouse.y-viewport.y)/viewport.scale}, inside
}

draw_canvas :: proc(canvas: rl.RenderTexture2D, viewport: CanvasViewport) {
    source := rl.Rectangle{0, 0, f32(CANVAS_W), -f32(CANVAS_H)}
    destination := rl.Rectangle{viewport.x, viewport.y, viewport.width, viewport.height}
    rl.DrawTexturePro(canvas.texture, source, destination, rl.Vector2{}, 0, rl.WHITE)
}
