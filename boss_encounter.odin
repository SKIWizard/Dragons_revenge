package main

import rl "vendor:raylib"
import "core:c"

BossEncounter :: enum {Waiting, Opening, Fighting, Defiance, Empowered, Won}

boss_index :: proc(w: ^World) -> int {
    for i := 0; i < w.enemy_count; i += 1 {
        if w.enemies[i].kind == .Boss { return i }
    }
    return -1
}

boss_in_view :: proc(w: ^World, camera_x: f32) -> bool {
    index := boss_index(w)
    if index < 0 || !w.enemies[index].alive { return false }
    left := f32(w.enemies[index].x)
    return left < camera_x+VIEW_W-8 && left+f32(BOSS_W) > camera_x+8
}

boss_is_defeated :: proc(w: ^World) -> bool {
    index := boss_index(w)
    return index >= 0 && !w.enemies[index].alive
}

boss_transformation_ready :: proc(encounter: BossEncounter, health: int) -> bool {
    return encounter == .Fighting && health <= 0
}

draw_ending_screen :: proc(art, title: rl.Texture2D) {
    rl.ClearBackground(rl.Color{38, 17, 32, 255})
    if rl.IsTextureValid(art) {
        rl.DrawTexturePro(art, rl.Rectangle{0, 0, f32(art.width), f32(art.height)},
            rl.Rectangle{0, 0, CANVAS_W, CANVAS_H}, rl.Vector2{}, 0, rl.WHITE)
    }
    rl.DrawRectangle(0, CANVAS_H-115, CANVAS_W, 115, rl.Color{20, 12, 27, 195})
    if rl.IsTextureValid(title) {
        rl.DrawTexture(title, c.int((CANVAS_W-int(title.width))/2), CANVAS_H-96, rl.WHITE)
    }
}
