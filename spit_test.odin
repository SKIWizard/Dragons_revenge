package main

import "core:testing"
import "core:math"

active_shot_count :: proc(state: ^SpitState) -> int {
    count := 0
    for shot in state.shots { if shot.active { count += 1 } }
    return count
}

@test
plasma_spray_is_fast_narrow_and_long_ranged :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    player := Player{x = 100, y = 100, facing = 1}
    set_player_collision(w, &player)
    inventory := Inventory{}
    inventory.slots[0] = InventorySlot{material = .Plasma, count = 100}
    state := SpitState{}
    testing.expect(t, spit_tick(w, &player, &inventory, &state, 600, 108, true) == 10)
    for shot in state.shots {
        if !shot.active { continue }
        speed := math.sqrt(shot.vx*shot.vx+shot.vy*shot.vy)
        testing.expect(t, speed >= PLASMA_MIN_SPEED && speed < PLASMA_MAX_SPEED+0.01)
        testing.expect(t, math.abs(shot.vy) < 0.12)
        testing.expect(t, shot.life_ticks >= PLASMA_MIN_LIFE && shot.life_ticks <= PLASMA_MAX_LIFE)
        testing.expect(t, shot.penetration_left == PLASMA_PENETRATION)
    }
}

@test
plasma_bolt_deletes_exactly_ten_material_cells :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    for x := 121; x <= 131; x += 1 { place(w, x, 100, .Stone) }
    state := SpitState{}
    state.shots[0] = FlyingParticle{x = 120, y = 100, vx = 16, material = .Plasma,
                                    life_ticks = PLASMA_MAX_LIFE, active = true,
                                    penetration_left = PLASMA_PENETRATION}
    update_flying_particles(w, &state)
    testing.expect(t, !state.shots[0].active)
    testing.expect(t, count_kind(w, .Stone) == 1)
    testing.expect(t, kind_at(w, 131, 100) == .Stone)
}

@test
fire_shot_expires_at_its_random_range :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    player := Player{x = 100, y = 100, facing = 1}
    set_player_collision(w, &player)
    inventory := starting_inventory()
    state := SpitState{}
    testing.expect(t, spit_one(w, &player, &inventory, &state, 600, 108, 0))
    start_x := state.shots[0].x
    life := state.shots[0].life_ticks
    vx, vy := state.shots[0].vx, state.shots[0].vy
    testing.expect(t, life >= SPRAY_MIN_LIFE && life <= SPRAY_MAX_LIFE)
    for _ in 0..<int(life)-1 { update_flying_particles(w, &state) }
    testing.expect(t, state.shots[0].active)
    testing.expect(t, state.shots[0].x >= start_x+60)
    testing.expect(t, state.shots[0].x <= start_x+135)
    testing.expect(t, state.shots[0].vx == vx && state.shots[0].vy == vy)
    update_flying_particles(w, &state)
    testing.expect(t, !state.shots[0].active)
    testing.expect(t, count_kind(w, .Fire) == 0)
}

@test
fire_stream_ignites_petrol_and_powder_on_contact :: proc(t: ^testing.T) {
    fuels := [2]Material{.Petrol, .Powder}
    for material in fuels {
        w := new(World)
        place(w, 123, 100, material)
        state := SpitState{}
        state.shots[0] = FlyingParticle{x = 120, y = 100, vx = 4,
                                        material = .Fire, life_ticks = 20, active = true}
        update_flying_particles(w, &state)
        testing.expect(t, kind_at(w, 123, 100) == .Boom)
        testing.expect(t, !state.shots[0].active)
        free(w)
    }
}

@test
all_materials_share_chaotic_constant_speed_spray :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    player := Player{x = 100, y = 100, facing = 1}
    set_player_collision(w, &player)
    inventory := Inventory{}
    inventory.slots[0] = InventorySlot{material = .Sand, count = 200}
    state := SpitState{}
    for _ in 0..<12 {
        testing.expect(t, spit_tick(w, &player, &inventory, &state, 600, 108, true) == SPRAY_PIXELS_PER_TICK)
    }
    testing.expect(t, active_shot_count(&state) == 120)
    testing.expect(t, inventory.slots[0].count == 80)
    min_speed, max_speed: f32 = 100, 0
    min_life, max_life := u16(1000), u16(0)
    for shot in state.shots {
        if !shot.active { continue }
        speed := math.sqrt(shot.vx*shot.vx+shot.vy*shot.vy)
        testing.expect(t, speed >= SPRAY_MIN_SPEED && speed < SPRAY_MAX_SPEED+0.05)
        testing.expect(t, shot.life_ticks >= SPRAY_MIN_LIFE && shot.life_ticks <= SPRAY_MAX_LIFE)
        min_speed = min(min_speed, speed)
        max_speed = max(max_speed, speed)
        min_life = min(min_life, shot.life_ticks)
        max_life = max(max_life, shot.life_ticks)
    }
    testing.expect(t, max_speed-min_speed > 0.2)
    testing.expect(t, max_life > min_life)
    testing.expect(t, state.shots[0].vx != state.shots[1].vx ||
                      state.shots[0].vy != state.shots[1].vy)
}

@test
finite_ammo_decreases_once_per_sprayed_pixel :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    player := Player{x = 100, y = 100, facing = 1}
    set_player_collision(w, &player)
    inventory := Inventory{}
    inventory.slots[0] = InventorySlot{material = .Snow, count = 13}
    state := SpitState{}
    testing.expect(t, spit_tick(w, &player, &inventory, &state, 600, 108, true) == 10)
    testing.expect(t, spit_tick(w, &player, &inventory, &state, 600, 108, true) == 3)
    testing.expect(t, inventory.slots[0].material == .Empty)
    testing.expect(t, active_shot_count(&state) == 13)
}

@test
sprayed_particles_cross_without_blocking_one_another :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    state := SpitState{}
    state.shots[0] = FlyingParticle{x = 120, y = 100, vx = 2.5, material = .Water,
                                    life_ticks = SPRAY_MAX_LIFE, active = true}
    state.shots[1] = FlyingParticle{x = 121, y = 100, vx = 2.5, material = .Water,
                                    life_ticks = SPRAY_MAX_LIFE, active = true}
    update_flying_particles(w, &state)
    testing.expect(t, active_shot_count(&state) == 2)
    testing.expect(t, state.shots[0].x > 120 && state.shots[1].x > 121)
    testing.expect(t, state.shots[0].vx == 2.5 && state.shots[1].vx == 2.5)
}

@test
powder_becomes_falling_world_material_when_spray_ends :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    for x := 90; x < 110; x += 1 { place(w, x, 80, .Stone) }
    state := SpitState{}
    state.shots[0] = FlyingParticle{x = 100, y = 30, material = .Sand,
                                    life_ticks = 1, active = true}
    update_flying_particles(w, &state)
    testing.expect(t, !state.shots[0].active)
    testing.expect(t, kind_at(w, 100, 30) == .Sand)
    for _ in 0..<20 { step_world(w) }
    testing.expect(t, count_kind(w, .Sand) == 1)
    testing.expect(t, kind_at(w, 100, 30) == .Empty)
}

@test
solid_keeps_falling_after_spray_then_attaches_to_floor :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    place(w, 100, 80, .Stone)
    state := SpitState{}
    state.shots[0] = FlyingParticle{x = 100, y = 30, material = .Wood,
                                    life_ticks = 1, active = true}
    update_flying_particles(w, &state)
    testing.expect(t, state.shots[0].active && state.shots[0].settling)
    for _ in 0..<70 { update_flying_particles(w, &state) }
    testing.expect(t, !state.shots[0].active)
    testing.expect(t, kind_at(w, 100, 79) == .Wood)
}

@test
solid_displaces_water_before_attaching :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    place(w, 100, 80, .Stone)
    place(w, 100, 79, .Water)
    before := count_kind(w, .Water)
    state := SpitState{}
    state.shots[0] = FlyingParticle{x = 100, y = 70, material = .Iron,
                                    life_ticks = 1, active = true}
    for _ in 0..<30 { update_flying_particles(w, &state) }
    testing.expect(t, !state.shots[0].active)
    testing.expect(t, kind_at(w, 100, 79) == .Iron)
    testing.expect(t, count_kind(w, .Water) == before)
}

@test
solid_spray_attaches_on_direct_solid_impact :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    for y := 90; y < 110; y += 1 { place(w, 110, y, .Stone) }
    state := SpitState{}
    state.shots[0] = FlyingParticle{x = 100, y = 100, vx = 3, material = .Wood,
                                    life_ticks = SPRAY_MAX_LIFE, active = true}
    for _ in 0..<6 { update_flying_particles(w, &state) }
    testing.expect(t, !state.shots[0].active)
    testing.expect(t, kind_at(w, 109, 100) == .Wood)
}

@test
fast_shot_checks_wall_cells_along_its_path :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    player := Player{x = 100, y = 100, facing = 1}
    set_player_collision(w, &player)
    for y := 0; y < 200; y += 1 { place(w, 135, y, .Stone) }
    inventory := starting_inventory()
    state := SpitState{}
    testing.expect(t, spit_one(w, &player, &inventory, &state, 600, 108, 0))
    for _ in 0..<20 { update_flying_particles(w, &state) }
    testing.expect(t, active_shot_count(&state) == 0)
    testing.expect(t, count_kind(w, .Stone) == 200)
    testing.expect(t, count_kind(w, .Fire) == 1)
    for y := 0; y < WORLD_H; y += 1 {
        for x := 135; x < WORLD_W; x += 1 {
            testing.expect(t, kind_at(w, x, y) != .Fire)
        }
    }
}
