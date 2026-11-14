package main

import rl "vendor:raylib"
import "core:c"

MaterialOption :: struct { name: cstring, kind: Material }
MATERIAL_OPTIONS :: [16]MaterialOption{
    {"Sand", .Sand}, {"Water", .Water}, {"Stone", .Stone},
    {"Smoke", .Smoke}, {"Wood", .Wood}, {"Fire", .Fire},
    {"Steam", .Steam}, {"Plasma", .Plasma}, {"Lava", .Lava},
    {"Powder", .Powder}, {"Explosion", .Boom}, {"Petrol", .Petrol},
    {"Acid", .Acid}, {"Iron", .Iron}, {"Snow", .Snow}, {"Potion", .Potion},
}

SandboxMenu :: struct {
    open: bool,
    unlocked: bool,
    code_progress: int,
    selected: Material,
}

secret_code := [5]rl.KeyboardKey{.I, .D, .D, .Q, .D}

feed_secret_key :: proc(menu: ^SandboxMenu, key: rl.KeyboardKey) {
    if menu.unlocked || key == .KEY_NULL { return }
    if key == secret_code[menu.code_progress] {
        menu.code_progress += 1
        if menu.code_progress == len(secret_code) {
            menu.code_progress = 0
            menu.unlocked = true
            menu.open = true
        }
    } else if key == .I {
        menu.code_progress = 1
    } else {
        menu.code_progress = 0
    }
}

MENU_X :: 12
MENU_Y :: 116
MENU_W :: 190
MENU_ROW_H :: 29

mouse_in :: proc(mx, my, x, y, width, height: int) -> bool {
    return mx >= x && mx < x+width && my >= y && my < y+height
}

spawn_sphere :: proc(w: ^World, x, y: int, material: Material, player: ^Player) {
    // A 20x20 cell bounding box, with a circular mask.
    for dy := -10; dy < 10; dy += 1 {
        for dx := -10; dx < 10; dx += 1 {
            if dx*dx+dy*dy >= 100 { continue }
            px, py := x+dx, y+dy
            if !inside(px, py) { continue }
            if px >= player.x && px < player.x+PLAYER_W &&
               py >= player.y && py < player.y+PLAYER_H { continue }
            place(w, px, py, material)
        }
    }
}

handle_sandbox_mouse :: proc(menu: ^SandboxMenu, w: ^World, p: ^Player,
                             camera_px_x, camera_px_y, mouse_x, mouse_y: int, mouse_inside: bool) {
    for {
        key := rl.GetKeyPressed()
        if key == .KEY_NULL { break }
        feed_secret_key(menu, key)
    }
    if !menu.unlocked { return }
    if rl.IsKeyPressed(.TAB) { menu.open = !menu.open }
    if !mouse_inside || !rl.IsMouseButtonPressed(.LEFT) { return }
    mx, my := mouse_x, mouse_y
    if mouse_in(mx, my, 12, 80, 190, 30) {
        menu.open = !menu.open
        return
    }
    if !menu.open { return }
    if menu.open && mouse_in(mx, my, MENU_X, MENU_Y, MENU_W, len(MATERIAL_OPTIONS)*MENU_ROW_H+14) {
        for option, row in MATERIAL_OPTIONS {
            if mouse_in(mx, my, MENU_X+6, MENU_Y+7+row*MENU_ROW_H, MENU_W-12, MENU_ROW_H-3) {
                menu.selected = option.kind
                return
            }
        }
        return
    }
    world_x := (mx+camera_px_x)/CELL_SIZE
    world_y := (my+camera_px_y)/CELL_SIZE
    spawn_sphere(w, world_x, world_y, menu.selected, p)
}

draw_sandbox_menu :: proc(menu: ^SandboxMenu, icon_sheet: rl.Texture2D) {
    if !menu.unlocked { return }
    rl.DrawRectangle(12, 80, 190, 30, rl.Color{32, 42, 49, 235})
    draw_material_icon(icon_sheet, menu.selected, 18, 87, 1)
    rl.DrawText("MATERIALS  [TAB]", 43, 88, 15, rl.WHITE)
    if !menu.open { return }
    rl.DrawRectangle(MENU_X, MENU_Y, MENU_W, len(MATERIAL_OPTIONS)*MENU_ROW_H+14, rl.Color{25, 33, 39, 238})
    for option, row in MATERIAL_OPTIONS {
        y := MENU_Y+7+row*MENU_ROW_H
        background := rl.Color{55, 67, 72, 255}
        if option.kind == menu.selected { background = rl.Color{91, 113, 91, 255} }
        rl.DrawRectangle(MENU_X+6, c.int(y), MENU_W-12, MENU_ROW_H-3, background)
        draw_material_icon(icon_sheet, option.kind, MENU_X+12, y+5, 1)
        rl.DrawText(option.name, MENU_X+36, c.int(y+6), 14, rl.WHITE)
    }
}
