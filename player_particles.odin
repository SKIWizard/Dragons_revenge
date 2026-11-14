package main

// The dragon is a solid shape to the cell simulation. Its visible sprite stays
// separate from the material grid; displaced particles keep their full Cell data.
PLAYER_PUSH_RADIUS :: 32
PLAYER_PUSH_SIDE :: PLAYER_PUSH_RADIUS*2+1
PLAYER_PUSH_AREA :: PLAYER_PUSH_SIDE*PLAYER_PUSH_SIDE

BodyShape :: enum { Dragon, Knight, Particle }

// Alpha silhouette of the first 24x24 Vita frame, mapped onto the 14x20
// controller hitbox (source x=4..17, y=1..20). Empty pixels let water touch
// the visible dragon instead of leaving a rectangular air pocket.
PLAYER_FLUID_MASK := [PLAYER_H]u16{
    0x0000, 0x0000, 0x0000, 0x3FFC, 0x3FFE,
    0x3FFF, 0x3FFF, 0x3FFF, 0x3FFE, 0x3FFE,
    0x3FFE, 0x0FF8, 0x0FF0, 0x0FFC, 0x0FFC,
    0x0FFC, 0x0FF8, 0x0FF0, 0x0770, 0x0330,
}

player_body_contains :: proc(x, y, player_x, player_y: int) -> bool {
    dx, dy := x-player_x, y-player_y
    if dx < 0 || dx >= PLAYER_W || dy < 0 || dy >= PLAYER_H { return false }
    return PLAYER_FLUID_MASK[dy] & (u16(1) << u16(dx)) != 0
}

body_contains :: proc(shape: BodyShape, x, y, body_x, body_y: int) -> bool {
    if shape == .Knight { return enemy_body_contains(x, y, body_x, body_y) }
    if shape == .Particle { return x == body_x && y == body_y }
    return player_body_contains(x, y, body_x, body_y)
}

enemy_at :: proc(w: ^World, x, y: int) -> int {
    for i := 0; i < w.enemy_count; i += 1 {
        enemy := &w.enemies[i]
        if enemy.alive && enemy_body_contains_kind(enemy.kind, x, y, enemy.x, enemy.y) { return i }
    }
    return -1
}

enemy_occupies :: proc(w: ^World, x, y: int) -> bool { return enemy_at(w, x, y) >= 0 }

actor_occupies :: proc(w: ^World, x, y: int) -> bool {
    return player_occupies(w, x, y) || enemy_occupies(w, x, y)
}

other_actor_occupies :: proc(w: ^World, x, y: int, shape: BodyShape, moving_enemy: int) -> bool {
    if shape != .Dragon && player_occupies(w, x, y) { return true }
    for i := 0; i < w.enemy_count; i += 1 {
        if shape == .Knight && i == moving_enemy { continue }
        enemy := &w.enemies[i]
        if enemy.alive && enemy_body_contains_kind(enemy.kind, x, y, enemy.x, enemy.y) { return true }
    }
    return false
}

player_occupies :: proc(w: ^World, x, y: int) -> bool {
    return w.player_collision_active &&
        player_body_contains(x, y, w.player_x, w.player_y)
}

set_player_collision :: proc(w: ^World, p: ^Player) {
    old_x, old_y := w.player_x, w.player_y
    had_collision := w.player_collision_active
    w.player_collision_active = true
    w.player_x, w.player_y = p.x, p.y
    if !had_collision || (old_x == p.x && old_y == p.y) { return }
    // The newly vacated shape can fill with liquid only if its neighbours wake.
    for y := old_y; y < old_y+PLAYER_H; y += 1 {
        for x := old_x; x < old_x+PLAYER_W; x += 1 {
            if player_body_contains(x, y, old_x, old_y) &&
               !player_body_contains(x, y, p.x, p.y) { wake_neighbors(w, x, y) }
        }
    }
}

// Find a continuous path through movable cells to an empty cell. Moving the
// chain backwards prevents deletion or teleporting through a solid wall.
push_particle_out_body :: proc(w: ^World, x, y, body_x, body_y: int, shape: BodyShape, moving_enemy: int) -> bool {
    previous: [PLAYER_PUSH_AREA]i32
    for i in 0..<PLAYER_PUSH_AREA { previous[i] = -1 }
    queue: [PLAYER_PUSH_AREA]i32
    start := PLAYER_PUSH_RADIUS*PLAYER_PUSH_SIDE+PLAYER_PUSH_RADIUS
    previous[start] = i32(start)
    queue[0] = i32(start)
    head, tail := 0, 1
    directions := [4][2]int{{0,-1}, {-1,0}, {1,0}, {0,1}}
    destination := -1
    for head < tail && destination < 0 {
        node := int(queue[head])
        head += 1
        local_x, local_y := node%PLAYER_PUSH_SIDE, node/PLAYER_PUSH_SIDE
        for direction in directions {
            next_x, next_y := local_x+direction[0], local_y+direction[1]
            if next_x < 0 || next_x >= PLAYER_PUSH_SIDE || next_y < 0 || next_y >= PLAYER_PUSH_SIDE { continue }
            next := next_y*PLAYER_PUSH_SIDE+next_x
            if previous[next] >= 0 { continue }
            world_x := x+next_x-PLAYER_PUSH_RADIUS
            world_y := y+next_y-PLAYER_PUSH_RADIUS
            in_body := body_contains(shape, world_x, world_y, body_x, body_y)
            if shape == .Knight && moving_enemy >= 0 {
                in_body = enemy_body_contains_kind(w.enemies[moving_enemy].kind, world_x, world_y, body_x, body_y)
            }
            if !inside(world_x, world_y) ||
               in_body ||
               other_actor_occupies(w, world_x, world_y, shape, moving_enemy) { continue }
            kind := kind_at(w, world_x, world_y)
            if solid(kind) { continue }
            previous[next] = i32(node)
            if kind == .Empty { destination = next; break }
            queue[tail] = i32(next)
            tail += 1
        }
    }
    if destination < 0 { return false }
    node := destination
    for node != start {
        parent := int(previous[node])
        swap_cells(
            w,
            x+parent%PLAYER_PUSH_SIDE-PLAYER_PUSH_RADIUS,
            y+parent/PLAYER_PUSH_SIDE-PLAYER_PUSH_RADIUS,
            x+node%PLAYER_PUSH_SIDE-PLAYER_PUSH_RADIUS,
            y+node/PLAYER_PUSH_SIDE-PLAYER_PUSH_RADIUS,
        )
        node = parent
    }
    return true
}

push_particle_out :: proc(w: ^World, x, y, player_x, player_y: int) -> bool {
    return push_particle_out_body(w, x, y, player_x, player_y, .Dragon, -1)
}

player_overlaps_enemy :: proc(player_x, player_y: int, enemy: ^Enemy) -> bool {
    for cy := max(player_y, enemy.y); cy < min(player_y+PLAYER_H, enemy.y+enemy_height(enemy.kind)); cy += 1 {
        for cx := max(player_x, enemy.x); cx < min(player_x+PLAYER_W, enemy.x+enemy_width(enemy.kind)); cx += 1 {
            if player_body_contains(cx, cy, player_x, player_y) &&
               enemy_body_contains_kind(enemy.kind, cx, cy, enemy.x, enemy.y) { return true }
        }
    }
    return false
}

player_can_enter :: proc(w: ^World, x, y, dy: int) -> bool {
    for cy := y; cy < y+PLAYER_H; cy += 1 {
        for cx := x; cx < x+PLAYER_W; cx += 1 {
            if cx < 0 || cx >= WORLD_W || cy < 0 { return false }
            if cy >= WORLD_H { continue }
            kind := kind_at(w, cx, cy)
            if solid(kind) || (dy > 0 && powder(kind)) { return false }
        }
    }
    for i := 0; i < w.enemy_count; i += 1 {
        enemy := &w.enemies[i]
        if !enemy.alive || !player_overlaps_enemy(x, y, enemy) { continue }
        if dy >= 0 || !lift_enemy_one_cell(w, i) || player_overlaps_enemy(x, y, enemy) { return false }
    }
    for cy := y; cy < y+PLAYER_H; cy += 1 {
        for cx := x; cx < x+PLAYER_W; cx += 1 {
            if cy >= WORLD_H { continue }
            if !player_body_contains(cx, cy, x, y) { continue }
            kind := kind_at(w, cx, cy)
            if !mobile(kind) { continue }
            if !push_particle_out(w, cx, cy, x, y) {
                // A liquid can be trapped briefly in a one-cell pocket between
                // the feet and the floor. It must not turn into a solid wall.
                if liquid(kind) || gas(kind) { continue }
                return false
            }
        }
    }
    return true
}
