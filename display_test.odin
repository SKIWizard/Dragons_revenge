package main

import "core:testing"
import rl "vendor:raylib"

@test
fullscreen_viewport_preserves_aim_coordinates :: proc(t: ^testing.T) {
    viewport := canvas_viewport(2400, 1000)
    testing.expect(t, viewport.width <= 2400 && viewport.height <= 1000)
    testing.expect(t, viewport.x > 0)
    center := rl.Vector2{viewport.x+viewport.width/2, viewport.y+viewport.height/2}
    mapped, inside := canvas_mouse(center, viewport)
    testing.expect(t, inside)
    testing.expect(t, abs(mapped.x-f32(CANVAS_W)/2) < 0.01)
    testing.expect(t, abs(mapped.y-f32(CANVAS_H)/2) < 0.01)
    _, inside = canvas_mouse(rl.Vector2{0, 500}, viewport)
    testing.expect(t, !inside)
}
