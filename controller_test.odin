package main

import "core:testing"

test_floor :: proc(w: ^World, x0, x1, y: int) {
    for x := x0; x < x1; x += 1 { place(w, x, y, .Stone) }
}

@test
controller_landing_and_buffer :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    test_floor(w, 0, 100, 50)
    p := Player{x = 20, y = 20, vy = 200}
    update_player(&p, w, Input{jump_pressed = true, jump_held = true})
    jumped := false
    for _ in 0..<12 {
        update_player(&p, w, Input{jump_held = true})
        if p.vy < 0 { jumped = true; break }
    }
    testing.expect(t, jumped)
    testing.expect(t, p.y+PLAYER_H <= 50)
    testing.expect(t, p.jump_buffer <= 0)
}

@test
controller_coyote_and_variable_height :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    test_floor(w, 0, 20, 150)
    p := Player{x = 5, y = 150-PLAYER_H}
    update_player(&p, w, Input{})
    p.x = 25
    update_player(&p, w, Input{jump_pressed = true, jump_held = true})
    testing.expect(t, p.vy < 0)
    short := Player{x = 5, y = 150-PLAYER_H}
    long := short
    update_player(&short, w, Input{jump_pressed = true, jump_held = true})
    update_player(&long, w, Input{jump_pressed = true, jump_held = true})
    for _ in 0..<18 {
        update_player(&short, w, Input{})
        update_player(&long, w, Input{jump_held = true})
    }
    testing.expect(t, long.y < short.y)
}

@test
controller_corner_and_wall_retention :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    place(w, 20, 99, .Stone)
    corner := Player{x = 20, y = 100, vy = -120}
    update_player(&corner, w, Input{})
    testing.expect(t, corner.x > 20 && corner.y < 100)

    place(w, 40, 120, .Stone)
    wall := Player{x = 26, y = 120, vx = 150}
    update_player(&wall, w, Input{direction = 1})
    testing.expect(t, wall.wall_retention > 0 && wall.retained_vx > 0)
    place(w, 40, 120, .Empty)
    update_player(&wall, w, Input{direction = 1})
    testing.expect(t, wall.vx > MAX_RUN_SPEED)
}

@test
small_ledge_steps_up_but_tall_wall_still_blocks :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    test_floor(w, 0, 100, 100)
    for y := 97; y < 100; y += 1 { place(w, 34, y, .Stone) }
    p := Player{x = 20, y = 80, vx = MAX_RUN_SPEED}
    update_player(&p, w, Input{direction = 1})
    testing.expect(t, p.x > 20)
    testing.expect(t, p.y == 77)

    wall_world := new(World)
    defer free(wall_world)
    test_floor(wall_world, 0, 100, 100)
    for y := 90; y < 100; y += 1 { place(wall_world, 34, y, .Stone) }
    blocked := Player{x = 20, y = 80, vx = MAX_RUN_SPEED}
    update_player(&blocked, wall_world, Input{direction = 1})
    testing.expect(t, blocked.x == 20)
    testing.expect(t, blocked.y == 80)
}
