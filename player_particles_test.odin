package main

import "core:testing"

@test
step_up_ignores_loose_particles_on_a_small_ledge :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    for x := 4; x < 75; x += 1 { place(w, x, 50, .Stone) }
    for x := 32; x < 37; x += 1 {
        place(w, x, 48, .Stone)
        place(w, x, 49, .Stone)
    }
    player := Player{x = 18, y = 30, facing = 1}
    set_player_collision(w, &player)
    // This grain can sit inside the transparent edge of the sprite while the
    // broad support probe still sees it. It must not turn a 2px step into a wall.
    place(w, 31, 48, .Sand)
    place(w, 32, 47, .Water)
    sand_before, water_before := count_kind(w, .Sand), count_kind(w, .Water)
    testing.expect(t, player_hits(w, player.x, player.y-1))
    testing.expect(t, !player_hits_static(w, player.x, player.y-1))
    testing.expect(t, try_step_up(&player, w, 1))
    testing.expect(t, player.x == 19 && player.y == 28)
    testing.expect(t, count_kind(w, .Sand) == sand_before)
    testing.expect(t, count_kind(w, .Water) == water_before)
}

@test
player_pushes_water_without_losing_particles :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    player := Player{x = 80, y = 80}
    set_player_collision(w, &player)
    for y := 82; y < 105; y += 1 {
        for x := 94; x < 110; x += 1 { place(w, x, y, .Water) }
    }
    before := count_kind(w, .Water)
    testing.expect(t, player_can_enter(w, 81, 80, 0))
    player.x = 81
    set_player_collision(w, &player)
    testing.expect(t, count_kind(w, .Water) == before)
    for y := player.y; y < player.y+PLAYER_H; y += 1 {
        for x := player.x; x < player.x+PLAYER_W; x += 1 {
            if player_body_contains(x, y, player.x, player.y) {
                testing.expect(t, kind_at(w, x, y) == .Empty)
            }
        }
    }
    for _ in 0..<30 { step_world(w) }
    testing.expect(t, count_kind(w, .Water) == before)
    for y := player.y; y < player.y+PLAYER_H; y += 1 {
        for x := player.x; x < player.x+PLAYER_W; x += 1 {
            if player_body_contains(x, y, player.x, player.y) {
                testing.expect(t, kind_at(w, x, y) == .Empty)
            }
        }
    }
}

@test
player_cannot_push_liquid_through_stone :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    for y := 10; y < 45; y += 1 {
        for x := 10; x < 45; x += 1 { place(w, x, y, .Stone) }
    }
    player := Player{x = 11, y = 15}
    set_player_collision(w, &player)
    testing.expect(t, !player_can_enter(w, 12, 15, 0))
}

@test
running_into_water_pushes_it_as_part_of_player_motion :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    player := Player{x = 80, y = 80}
    set_player_collision(w, &player)
    for x := 70; x < 130; x += 1 { place(w, x, 100, .Stone) }
    for y := 84; y < 100; y += 1 {
        for x := 95; x < 113; x += 1 { place(w, x, y, .Water) }
    }
    before := count_kind(w, .Water)
    start_x := player.x
    for _ in 0..<12 {
        update_player(&player, w, Input{direction = 1})
        step_world(w)
    }
    testing.expect(t, player.x > start_x+5)
    testing.expect(t, count_kind(w, .Water) == before)
    for y := player.y; y < player.y+PLAYER_H; y += 1 {
        for x := player.x; x < player.x+PLAYER_W; x += 1 {
            if player_body_contains(x, y, player.x, player.y) {
                testing.expect(t, kind_at(w, x, y) == .Empty)
            }
        }
    }
}

@test
water_can_fill_transparent_pixels_near_dragons_head :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    player := Player{x = 80, y = 80}
    set_player_collision(w, &player)
    testing.expect(t, !player_body_contains(85, 80, player.x, player.y))
    place(w, 85, 80, .Water)
    testing.expect(t, kind_at(w, 85, 80) == .Water)
    testing.expect(t, player_body_contains(85, 86, player.x, player.y))
    place(w, 85, 86, .Water)
    testing.expect(t, kind_at(w, 85, 86) == .Empty)
}

@test
jump_allowed_when_solid_is_just_below_feet_under_water :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    player := Player{x = 80, y = 80}
    for x := 80; x < 80+PLAYER_W; x += 1 { place(w, x, 103, .Stone) }
    place(w, 86, 101, .Water)
    testing.expect(t, !player_hits(w, player.x, player.y+1))
    testing.expect(t, player_near_support(w, player.x, player.y))
    update_player(&player, w, Input{jump_pressed = true, jump_held = true})
    testing.expect(t, player.vy < 0)
    testing.expect(t, player.y < 80)
}

@test
landing_in_water_then_reversing_keeps_movement_and_jump :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    player := Player{x = 80, y = 80}
    set_player_collision(w, &player)
    for x := 70; x < 140; x += 1 { place(w, x, 100, .Stone) }
    for y := 82; y < 100; y += 1 {
        for x := 95; x < 120; x += 1 { place(w, x, y, .Water) }
    }
    for _ in 0..<20 {
        update_player(&player, w, Input{direction = 1})
        step_world(w)
    }
    rightmost := player.x
    for _ in 0..<20 {
        update_player(&player, w, Input{direction = -1})
        step_world(w)
    }
    testing.expect(t, rightmost > 85)
    testing.expect(t, player.x < rightmost)
    update_player(&player, w, Input{jump_pressed = true, jump_held = true})
    testing.expect(t, player.vy < 0)
}
