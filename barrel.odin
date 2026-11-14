package main

import rl "vendor:raylib"

BARREL_W :: 20
BARREL_H :: 24
BARREL_FRAMES :: 6
BARREL_FRAME_TIME :: f32(0.09)
BARREL_CONTENT_AMOUNT :: 2000
BARREL_EAT_FRAME_TIME :: f32(0.09)
BARREL_EAT_FRAMES :: 8
BARREL_BITE_TIME :: f32(0.36)
BARREL_REACH :: 30

Barrel :: struct {
    x, y: int,
    material: Material,
    broken: bool,
    finished: bool,
    consuming: bool,
    consumed: bool,
    animation_time: f32,
    eat_time: f32,
}

barrel_has_pixel :: proc(dx, dy: int) -> bool {
    if dx < 0 || dx >= BARREL_W || dy < 0 || dy >= BARREL_H { return false }
    return BARREL_MASK[dy] & (u32(1) << u32(dx)) != 0
}

place_barrel :: proc(w: ^World, barrel: ^Barrel) {
    for dy := 0; dy < BARREL_H; dy += 1 {
        for dx := 0; dx < BARREL_W; dx += 1 {
            if barrel_has_pixel(dx, dy) { place(w, barrel.x+dx, barrel.y+dy, .Wood) }
        }
    }
}

barrel_damaged :: proc(w: ^World, barrel: ^Barrel) -> bool {
    for dy := 0; dy < BARREL_H; dy += 1 {
        for dx := 0; dx < BARREL_W; dx += 1 {
            if barrel_has_pixel(dx, dy) && kind_at(w, barrel.x+dx, barrel.y+dy) != .Wood { return true }
        }
    }
    return false
}

barrel_in_reach :: proc(barrel: ^Barrel, player: ^Player) -> bool {
    center_x := player.x+PLAYER_W/2
    center_y := player.y+PLAYER_H/2
    barrel_x := barrel.x+BARREL_W/2
    barrel_y := barrel.y+BARREL_H/2
    dx, dy := center_x-barrel_x, center_y-barrel_y
    return dx >= -BARREL_REACH && dx <= BARREL_REACH &&
           dy >= -BARREL_H && dy <= BARREL_H
}

begin_eat_barrel :: proc(barrel: ^Barrel, player: ^Player, inventory: ^Inventory) -> bool {
    if barrel.broken || barrel.consuming || !barrel_in_reach(barrel, player) ||
       !inventory_can_add(inventory, barrel.material) { return false }
    barrel.consuming = true
    barrel.eat_time = 0
    player.facing = 1
    if player.x+PLAYER_W/2 > barrel.x+BARREL_W/2 { player.facing = -1 }
    player.vx, player.vy = 0, 0
    player.remainder_x, player.remainder_y = 0, 0
    return true
}

break_barrel :: proc(w: ^World, barrel: ^Barrel, player: ^Player, inventory: ^Inventory, eaten: bool) {
    barrel.broken = true
    barrel.consumed = eaten
    barrel.animation_time = 0
    for dy := 0; dy < BARREL_H; dy += 1 {
        for dx := 0; dx < BARREL_W; dx += 1 {
            nx, ny := barrel.x+dx, barrel.y+dy
            if barrel_has_pixel(dx, dy) && kind_at(w, nx, ny) == .Wood { place(w, nx, ny, .Empty) }
        }
    }
    if eaten {
        inventory_add(inventory, barrel.material, BARREL_CONTENT_AMOUNT)
    } else {
        spawn_sphere(w, barrel.x+BARREL_W/2, barrel.y+BARREL_H/2, barrel.material, player)
    }
}

update_barrel :: proc(w: ^World, barrel: ^Barrel, player: ^Player, inventory: ^Inventory) {
    if barrel.consuming {
        barrel.eat_time += PHYSICS_DT
        if !barrel.broken && barrel_damaged(w, barrel) {
            barrel.consuming = false
            break_barrel(w, barrel, player, inventory, false)
        } else if !barrel.broken && barrel.eat_time >= BARREL_BITE_TIME {
            break_barrel(w, barrel, player, inventory, true)
        }
        if barrel.eat_time >= BARREL_EAT_FRAME_TIME*BARREL_EAT_FRAMES {
            barrel.consuming = false
        }
    } else if !barrel.broken && barrel_damaged(w, barrel) {
        break_barrel(w, barrel, player, inventory, false)
    }
    if barrel.broken && !barrel.finished {
        barrel.animation_time += PHYSICS_DT
        if barrel.animation_time >= BARREL_FRAME_TIME*BARREL_FRAMES { barrel.finished = true }
    }
}

draw_barrel :: proc(barrel: ^Barrel, texture, icon_sheet: rl.Texture2D, camera_px_x, camera_px_y: int) {
    if barrel.finished || !rl.IsTextureValid(texture) { return }
    frame := 0
    if barrel.broken {
        frame = int(barrel.animation_time/BARREL_FRAME_TIME)
        if frame >= BARREL_FRAMES { frame = BARREL_FRAMES-1 }
    }
    source := rl.Rectangle{f32(frame*BARREL_W), 0, BARREL_W, BARREL_H}
    destination := rl.Rectangle{f32(barrel.x*CELL_SIZE-camera_px_x), f32(barrel.y*CELL_SIZE-camera_px_y), BARREL_W*CELL_SIZE, BARREL_H*CELL_SIZE}
    rl.DrawTexturePro(texture, source, destination, rl.Vector2{}, 0, rl.WHITE)
    if !barrel.broken {
        icon_x := barrel.x*CELL_SIZE-camera_px_x+(BARREL_W*CELL_SIZE-32)/2
        icon_y := barrel.y*CELL_SIZE-camera_px_y+(BARREL_H*CELL_SIZE-32)/2
        draw_material_icon(icon_sheet, barrel.material, icon_x, icon_y, 2)
    }
}
