package main

import "core:testing"

@test
dino_animation_uses_requested_frames :: proc(t: ^testing.T) {
    for i := 0; i < 4; i += 1 {
        testing.expect(t, animation_frame(.Idle, f32(i)*0.15+0.001) == i)
    }
    for i := 0; i < 7; i += 1 {
        testing.expect(t, animation_frame(.Walk, f32(i)*0.09+0.001) == i+4)
    }
    testing.expect(t, animation_frame(.Air, 10) == 0)
}
