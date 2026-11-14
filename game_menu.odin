package main

import rl "vendor:raylib"
import "core:c"

GameScreen :: enum {Title, Settings, Playing, GameOver, Ending}

MENU_BUTTON_X :: 390
MENU_BUTTON_W :: 300
MENU_BUTTON_H :: 62
MENU_PLAY_Y :: 265
MENU_SETTINGS_Y :: 345
MENU_SLIDER_X :: 320
MENU_SLIDER_Y :: 338
MENU_SLIDER_W :: 440
MENU_BACK_Y :: 451

menu_contains :: proc(mx, my, x, y, width, height: int) -> bool {
    return mx >= x && mx < x+width && my >= y && my < y+height
}

update_game_menu :: proc(screen: ^GameScreen, volume: ^f32, mx, my: int,
                         click, held, play_key, settings_key, back_key, left_key, right_key: bool) -> bool {
    if screen^ == .Title {
        if play_key || (click && menu_contains(mx, my, MENU_BUTTON_X, MENU_PLAY_Y, MENU_BUTTON_W, MENU_BUTTON_H)) {
            screen^ = .Playing
            return true
        }
        if settings_key || (click && menu_contains(mx, my, MENU_BUTTON_X, MENU_SETTINGS_Y, MENU_BUTTON_W, MENU_BUTTON_H)) {
            screen^ = .Settings
        }
    } else if screen^ == .Settings {
        if back_key || (click && menu_contains(mx, my, MENU_BUTTON_X, MENU_BACK_Y, MENU_BUTTON_W, MENU_BUTTON_H)) {
            screen^ = .Title
        } else {
            if held && menu_contains(mx, my, MENU_SLIDER_X-12, MENU_SLIDER_Y-19, MENU_SLIDER_W+24, 56) {
                volume^ = f32(max(0, min(MENU_SLIDER_W, mx-MENU_SLIDER_X)))/MENU_SLIDER_W
            }
            if left_key { volume^ = max(0, volume^-0.05) }
            if right_key { volume^ = min(1, volume^+0.05) }
        }
    }
    return false
}

draw_menu_label :: proc(texture: rl.Texture2D, center_x, y: int) {
    if !rl.IsTextureValid(texture) { return }
    rl.DrawTexture(texture, c.int(center_x-int(texture.width)/2), c.int(y), rl.WHITE)
}

draw_menu_button :: proc(label: rl.Texture2D, x, y, width, height, mx, my: int) {
    hovered := menu_contains(mx, my, x, y, width, height)
    border := rl.Color{176, 137, 88, 255}
    if hovered { border = rl.Color{255, 211, 132, 255} }
    rl.DrawRectangle(c.int(x), c.int(y), c.int(width), c.int(height), border)
    rl.DrawRectangle(c.int(x+4), c.int(y+4), c.int(width-8), c.int(height-8), rl.Color{30, 35, 53, 245})
    if rl.IsTextureValid(label) {
        draw_menu_label(label, x+width/2, y+(height-int(label.height))/2)
    }
}

draw_game_menu :: proc(screen: GameScreen, volume: f32, brick: rl.Texture2D,
                       labels: [4]rl.Texture2D, mx, my: int) {
    rl.ClearBackground(rl.Color{37, 39, 55, 255})
    if rl.IsTextureValid(brick) {
        tile := int(brick.width)*4
        for y := 0; y < CANVAS_H; y += tile {
            for x := 0; x < CANVAS_W; x += tile {
                rl.DrawTexturePro(brick, rl.Rectangle{0, 0, f32(brick.width), f32(brick.height)},
                    rl.Rectangle{f32(x), f32(y), f32(tile), f32(tile)}, rl.Vector2{}, 0, rl.WHITE)
            }
        }
    }
    rl.DrawRectangle(0, 0, CANVAS_W, CANVAS_H, rl.Color{8, 12, 24, 95})
    rl.DrawText("DRAGONS REVENGE", 284, 111, 44, rl.Color{252, 218, 154, 255})
    rl.DrawRectangle(275, 173, 530, 3, rl.Color{160, 114, 76, 255})
    if screen == .Title {
        draw_menu_button(labels[0], MENU_BUTTON_X, MENU_PLAY_Y, MENU_BUTTON_W, MENU_BUTTON_H, mx, my)
        draw_menu_button(labels[1], MENU_BUTTON_X, MENU_SETTINGS_Y, MENU_BUTTON_W, MENU_BUTTON_H, mx, my)
    } else {
        draw_menu_label(labels[2], CANVAS_W/2, 269)
        rl.DrawRectangle(MENU_SLIDER_X-5, MENU_SLIDER_Y-5, MENU_SLIDER_W+10, 22, rl.Color{173, 139, 94, 255})
        rl.DrawRectangle(MENU_SLIDER_X, MENU_SLIDER_Y, MENU_SLIDER_W, 12, rl.Color{28, 31, 47, 255})
        fill := int(f32(MENU_SLIDER_W)*volume+0.5)
        rl.DrawRectangle(MENU_SLIDER_X, MENU_SLIDER_Y, c.int(fill), 12, rl.Color{245, 187, 99, 255})
        rl.DrawRectangle(c.int(MENU_SLIDER_X+fill-6), MENU_SLIDER_Y-8, 12, 28, rl.Color{255, 225, 155, 255})
        rl.DrawText(rl.TextFormat("%d%%", int(volume*100+0.5)), 510, 375, 24, rl.WHITE)
        draw_menu_button(labels[3], MENU_BUTTON_X, MENU_BACK_Y, MENU_BUTTON_W, MENU_BUTTON_H, mx, my)
    }
    rl.DrawCircle(c.int(mx), c.int(my), 5, rl.Color{255, 229, 164, 255})
    rl.DrawCircle(c.int(mx), c.int(my), 2, rl.Color{35, 35, 48, 255})
}
