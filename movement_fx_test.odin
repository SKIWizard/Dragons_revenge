package main

import "core:testing"

active_fx_count :: proc(fx: ^MovementFX) -> int {
    count := 0
    for particle in fx.particles {
        if particle.life > 0 { count += 1 }
    }
    return count
}

@test
run_and_turn_emit_ground_colored_particles :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    for x := 0; x < 100; x += 1 { place(w, x, 100, .Stone) }
    p := Player{x = 20, y = 80, vx = MAX_RUN_SPEED, grounded = true}
    fx := MovementFX{random_state = 1, last_direction = 1}
    old_x := p.x
    update_player(&p, w, Input{direction = 1})
    update_movement_fx(&fx, w, &p, old_x, 80, MAX_RUN_SPEED, 0, true, 1)
    testing.expect(t, active_fx_count(&fx) > 0)
    before_turn := active_fx_count(&fx)
    update_movement_fx(&fx, w, &p, p.x, p.y, MAX_RUN_SPEED, 0, true, -1)
    testing.expect(t, active_fx_count(&fx) >= before_turn+11)
    testing.expect(t, count_kind(w, .Stone) == 100)
}

@test
jump_and_landing_emit_then_expire :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    for x := 0; x < 100; x += 1 { place(w, x, 100, .Wood) }
    p := Player{x = 20, y = 80, grounded = true}
    fx := MovementFX{random_state = 2}
    update_player(&p, w, Input{jump_pressed = true, jump_held = true})
    update_movement_fx(&fx, w, &p, 20, 80, 0, 0, true, 0)
    testing.expect(t, active_fx_count(&fx) == 7)
    p.y = 80
    p.grounded = true
    p.vy = 0
    update_movement_fx(&fx, w, &p, 20, 80, 0, 100, false, 0)
    testing.expect(t, active_fx_count(&fx) == 16)
    for _ in 0..<45 { update_movement_fx(&fx, w, &p, 20, 80, 0, 0, true, 0) }
    testing.expect(t, active_fx_count(&fx) == 0)
    testing.expect(t, count_kind(w, .Wood) == 100)
}
