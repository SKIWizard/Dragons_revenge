package main

import "core:testing"

@test
static_materials_sleep_until_affected :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    place(w, 20, 20, .Stone)
    place(w, 21, 20, .Wood)
    testing.expect(t, w.active_count == 0)
    step_world(w)
    testing.expect(t, w.active_count == 0)
    place(w, 21, 19, .Fire)
    testing.expect(t, w.active_count > 0)
    for _ in 0..<15 { step_world(w) }
    testing.expect(t, w.cells[index(21, 20)].kind == .Wood)
    testing.expect(t, w.cells[index(21, 20)].burning)
    for _ in 0..<60 { step_world(w) }
    testing.expect(t, w.cells[index(21, 20)].kind != .Wood)
}

@test
ordinary_fire_ignites_nearby_fuel_quickly :: proc(t: ^testing.T) {
    fuels := [2]Material{.Petrol, .Powder}
    for fuel in fuels {
        w := new(World)
        w.random_state = 9
        for x := 98; x <= 102; x += 1 { place(w, x, 101, .Stone) }
        place(w, 99, 100, .Stone)
        place(w, 101, 100, .Stone)
        place(w, 100, 100, fuel)
        place(w, 100, 99, .Fire)
        for _ in 0..<2 { step_world(w) }
        testing.expect(t, w.blast_spark_count > 0)
        free(w)
    }
}

@test
detached_solids_remain_static :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    place(w, 50, 100, .Stone)
    place(w, 50, 99, .Wood)
    place(w, 50, 100, .Empty)
    for _ in 0..<40 { step_world(w) }
    testing.expect(t, kind_at(w, 50, 99) == .Wood)
}

@test
acid_erodes_stone_and_wakes_neighbours :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    place(w, 40, 40, .Stone)
    place(w, 40, 39, .Acid)
    for _ in 0..<11 { step_world(w) }
    testing.expect(t, w.cells[index(40, 40)].kind != .Stone)
}

@test
spawn_sphere_is_about_twenty_cells_wide :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    p := Player{x = 200, y = 200}
    spawn_sphere(w, 80, 80, .Water, &p)
    count := 0
    for y := 70; y < 90; y += 1 {
        for x := 70; x < 90; x += 1 {
            if kind_at(w, x, y) == .Water { count += 1 }
        }
    }
    testing.expect(t, count > 280 && count < 320)
}

count_kind :: proc(w: ^World, kind: Material) -> int {
    result := 0
    for cell in w.cells {
        if cell.kind == kind { result += 1 }
    }
    return result
}

@test
potion_heals_only_while_touching_and_then_expires :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    player := Player{x = 50, y = 80, health = 70}
    place(w, 51, 99, .Potion)
    for _ in 0..<24 { heal_from_potion(w, &player) }
    testing.expect(t, player.health == 72)
    place(w, 51, 99, .Empty)
    for _ in 0..<24 { heal_from_potion(w, &player) }
    testing.expect(t, player.health == 72)
    place(w, 65, 99, .Potion)
    for _ in 0..<270 { step_world(w) }
    testing.expect(t, count_kind(w, .Potion) == 0)
}

@test
water_and_sand_conserve_particles_while_moving :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    for x := 20; x < 80; x += 1 { place(w, x, 100, .Stone) }
    for y := 75; y < 100; y += 1 {
        place(w, 20, y, .Stone)
        place(w, 79, y, .Stone)
    }
    for y := 80; y < 90; y += 1 {
        for x := 30; x < 50; x += 1 { place(w, x, y, .Water) }
    }
    for x := 35; x < 45; x += 1 { place(w, x, 78, .Sand) }
    before_water := count_kind(w, .Water)
    before_sand := count_kind(w, .Sand)
    for _ in 0..<120 { step_world(w) }
    testing.expect(t, count_kind(w, .Water) == before_water)
    testing.expect(t, count_kind(w, .Sand) == before_sand)
}

@test
denser_material_sinks_without_horizontal_swaps :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    for x := 9; x <= 11; x += 1 { place(w, x, 12, .Stone) }
    place(w, 9, 11, .Stone)
    place(w, 11, 11, .Stone)
    place(w, 9, 10, .Stone)
    place(w, 11, 10, .Stone)
    place(w, 10, 11, .Water)
    place(w, 10, 10, .Sand)
    for _ in 0..<10 { step_world(w) }
    testing.expect(t, kind_at(w, 10, 11) == .Sand)
    testing.expect(t, kind_at(w, 10, 10) == .Water)
}

@test
water_sinks_below_petrol :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    for x := 19; x <= 21; x += 1 { place(w, x, 22, .Stone) }
    for y := 20; y <= 21; y += 1 {
        place(w, 19, y, .Stone)
        place(w, 21, y, .Stone)
    }
    place(w, 20, 21, .Petrol)
    place(w, 20, 20, .Water)
    for _ in 0..<12 { step_world(w) }
    testing.expect(t, kind_at(w, 20, 21) == .Water)
    testing.expect(t, kind_at(w, 20, 20) == .Petrol)
}

@test
lava_and_water_keep_two_material_cells :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    place(w, 60, 60, .Lava)
    place(w, 61, 60, .Water)
    step_world(w)
    testing.expect(t, count_kind(w, .Lava) == 1)
    testing.expect(t, count_kind(w, .Steam) == 1)
    testing.expect(t, count_kind(w, .Stone) == 0)
}

@test
settled_water_sleeps_and_wakes_when_wall_opens :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    for x := 39; x <= 42; x += 1 { place(w, x, 50, .Stone) }
    place(w, 39, 49, .Stone)
    place(w, 41, 49, .Stone)
    place(w, 40, 49, .Water)
    for _ in 0..<20 { step_world(w) }
    testing.expect(t, w.active_count == 0)
    place(w, 41, 49, .Empty)
    testing.expect(t, w.active_count > 0)
    for _ in 0..<10 { step_world(w) }
    testing.expect(t, kind_at(w, 40, 49) == .Empty)
}

@test
steam_uses_distinct_boiling_and_condensation_thresholds :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    place(w, 70, 70, .Water)
    w.cells[index(70, 70)].temperature = 101
    step_world(w)
    testing.expect(t, kind_at(w, 70, 70) == .Steam)
    testing.expect(t, w.cells[index(70, 70)].life >= 240 && w.cells[index(70, 70)].life <= 480)
    w.cells[index(70, 70)].temperature = 95
    step_world(w)
    testing.expect(t, count_kind(w, .Steam) == 1)
    for i in 0..<len(w.cells) {
        if w.cells[i].kind == .Steam { w.cells[i].temperature = 89; break }
    }
    step_world(w)
    testing.expect(t, count_kind(w, .Steam) == 1)
    for i in 0..<len(w.cells) {
        if w.cells[i].kind == .Steam { w.cells[i].life = 0; break }
    }
    step_world(w)
    testing.expect(t, count_kind(w, .Water) == 1)
}

@test
powder_and_water_do_not_sleep_midair :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    p := Player{x = 500, y = 200}
    spawn_sphere(w, 100, 80, .Sand, &p)
    spawn_sphere(w, 160, 80, .Water, &p)
    for _ in 0..<200 { step_world(w) }
    airborne := 0
    for y := 0; y < 200; y += 1 {
        for x := 70; x < 190; x += 1 {
            k := kind_at(w, x, y)
            if k == .Sand || k == .Water { airborne += 1 }
        }
    }
    testing.expect(t, airborne == 0)
}

@test
petrol_and_powder_ignite_into_explosions :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    place(w, 30, 30, .Petrol)
    place(w, 40, 30, .Powder)
    w.cells[index(30, 30)].temperature = 150
    w.cells[index(40, 30)].temperature = 190
    step_world(w)
    testing.expect(t, count_kind(w, .Boom) == 2)
}

@test
iron_transmits_fire_heat_to_water :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    for x := 29; x <= 31; x += 1 {
        place(w, x, 52, .Stone)
        place(w, x, 50, .Iron)
    }
    place(w, 29, 51, .Stone)
    place(w, 31, 51, .Stone)
    place(w, 30, 49, .Water)
    place(w, 29, 49, .Stone)
    place(w, 31, 49, .Stone)
    place(w, 30, 51, .Fire)
    w.cells[index(30, 51)].life = 90
    for _ in 0..<65 { step_world(w) }
    testing.expect(t, count_kind(w, .Steam) > 0)
}

@test
free_particles_cannot_sleep_before_falling :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    place(w, 100, 50, .Sand)
    place(w, 120, 50, .Water)
    w.cells[index(100,50)].rest_ticks = 7
    w.cells[index(120,50)].rest_ticks = 7
    for _ in 0..<20 { step_world(w) }
    testing.expect(t, count_kind(w, .Sand) == 1 && count_kind(w, .Water) == 1)
    testing.expect(t, kind_at(w,100,50) == .Empty)
    testing.expect(t, kind_at(w,120,50) == .Empty)
}

@test
explosion_breaks_stone_and_sends_sparks_outward :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    for x := 50; x < 80; x += 1 { place(w, x, 80, .Stone) }
    before := count_kind(w, .Stone)
    for x := 55; x < 75; x += 1 { place(w, x, 79, .Boom) }
    step_world(w)
    remaining := count_kind(w, .Stone)
    testing.expect(t, remaining < before/2)
    testing.expect(t, w.blast_spark_count > 0)
}

@test
explosion_breaches_wooden_wall :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    for y := 90; y <= 110; y += 1 {
        for x := 100; x <= 106; x += 1 { place(w, x, y, .Wood) }
    }
    place(w, 99, 100, .Boom)
    step_world(w)
    for x := 100; x <= 106; x += 1 {
        testing.expect(t, kind_at(w, x, 100) != .Wood)
    }
}

@test
explosion_ignites_distant_fuel_in_every_direction :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    place(w, 100, 100, .Boom)
    place(w, 114, 100, .Powder)
    place(w, 86, 100, .Petrol)
    place(w, 100, 86, .Petrol)
    place(w, 100, 114, .Powder)
    step_world(w)
    testing.expect(t, kind_at(w, 114, 100) == .Boom)
    testing.expect(t, kind_at(w, 86, 100) == .Boom)
    testing.expect(t, kind_at(w, 100, 86) == .Boom)
    testing.expect(t, kind_at(w, 100, 114) == .Boom)
}

@test
free_plasma_disappears_after_eroding_ten_cells :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    place(w, 100, 100, .Plasma)
    for _ in 0..<9 {
        place(w, 100, 99, .Stone)
        react_cell(w, 100, 100)
        testing.expect(t, kind_at(w, 100, 99) == .Empty)
        testing.expect(t, kind_at(w, 100, 100) == .Plasma)
    }
    place(w, 100, 99, .Stone)
    react_cell(w, 100, 100)
    testing.expect(t, kind_at(w, 100, 99) == .Empty)
    testing.expect(t, kind_at(w, 100, 100) == .Empty)
}

@test
liquid_uses_simple_down_then_side_rule :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    place(w, 100, 40, .Water)
    step_world(w)
    testing.expect(t, kind_at(w, 100, 41) == .Water)
    testing.expect(t, kind_at(w, 99, 40) == .Empty)
    testing.expect(t, kind_at(w, 101, 40) == .Empty)

    place(w, 200, 50, .Stone)
    place(w, 200, 49, .Water)
    step_world(w)
    testing.expect(t, kind_at(w, 200, 49) == .Empty)
    testing.expect(t, kind_at(w, 199, 49) == .Water || kind_at(w, 201, 49) == .Water)
}

@test
steam_lifetimes_vary_per_particle :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    first: i16 = 0
    varied := false
    for x := 10; x < 30; x += 1 {
        place(w, x, 10, .Steam)
        life := w.cells[index(x, 10)].life
        testing.expect(t, life >= 240 && life <= 480)
        if x == 10 { first = life }
        if life != first { varied = true }
    }
    testing.expect(t, varied)
}
