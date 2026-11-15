package main

import "core:testing"

enemy_test_floor :: proc(w: ^World) {
    for x := 0; x < 260; x += 1 { place(w, x, 100, .Stone) }
}

@test
boss_breaks_stalemate_next_to_stationary_player :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    enemy_test_floor(w)
    player := Player{x = 40, y = 80, health = PLAYER_MAX_HEALTH}
    set_player_collision(w, &player)
    w.enemies[0] = Enemy{kind = .Boss, x = 50, y = 63, health = BOSS_HEALTH,
                         facing = -1, alive = true, grounded = true, alert_time = 4}
    w.enemy_count = 1
    escaped := false
    for _ in 0..<45 {
        update_enemies(w, &player)
        if w.enemies[0].retreat_timer > 0 && w.enemies[0].vy < 0 { escaped = true }
    }
    testing.expect(t, escaped)
}

@test
dragon_can_walk_out_of_accidental_boss_overlap :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    player := Player{x = 65, y = 80, health = PLAYER_MAX_HEALTH}
    set_player_collision(w, &player)
    w.enemies[0] = Enemy{kind = .Boss, x = 70, y = 65,
                         health = BOSS_HEALTH, alive = true}
    w.enemy_count = 1
    current := player_enemy_overlap_count(player.x, player.y, &w.enemies[0])
    testing.expect(t, current > 0)
    testing.expect(t, player_enemy_overlap_count(player.x-1, player.y, &w.enemies[0]) < current)
    testing.expect(t, player_can_enter(w, player.x-1, player.y, 0))
}

@test
knight_chases_and_hits_player_once_per_attack :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    enemy_test_floor(w)
    player := Player{x = 60, y = 80, health = PLAYER_MAX_HEALTH}
    set_player_collision(w, &player)
    w.enemies[0] = Enemy{x = 100, y = 89, health = ENEMY_HEALTH, facing = -1, alive = true, grounded = true}
    w.enemy_count = 1
    for _ in 0..<62 { update_enemies(w, &player) }
    testing.expect(t, w.enemies[0].x < 100)
    testing.expect(t, player.health == 90)
}

@test
knight_jumps_over_wall_while_chasing :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    enemy_test_floor(w)
    for y := 76; y < 100; y += 1 { place(w, 90, y, .Wood) }
    player := Player{x = 48, y = 80, health = PLAYER_MAX_HEALTH}
    set_player_collision(w, &player)
    w.enemies[0] = Enemy{x = 120, y = 89, health = ENEMY_HEALTH, facing = -1,
                         alive = true, grounded = true, alert_time = 4}
    w.enemy_count = 1
    for _ in 0..<120 { update_enemies(w, &player) }
    testing.expect(t, w.enemies[0].x < 90)
    testing.expect(t, !enemy_hits(w, w.enemies[0].x, w.enemies[0].y))
}

@test
knight_pushes_water_without_deleting_it :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    w.enemies[0] = Enemy{x = 38, y = 44, health = ENEMY_HEALTH, alive = true}
    w.enemy_count = 1
    for y := 44; y < 58; y += 1 {
        for x := 42; x < 55; x += 1 { place(w, x, y, .Water) }
    }
    before := count_kind(w, .Water)
    testing.expect(t, enemy_can_enter(w, 0, 39, 44, 0))
    testing.expect(t, count_kind(w, .Water) == before)
    for y := 44; y < 44+ENEMY_H; y += 1 {
        for x := 39; x < 39+ENEMY_W; x += 1 {
            if enemy_body_contains(x, y, 39, 44) { testing.expect(t, kind_at(w, x, y) == .Empty) }
        }
    }
}

@test
dragon_jump_carries_knight_above_it :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    enemy_test_floor(w)
    player := Player{x = 60, y = 80, health = PLAYER_MAX_HEALTH}
    set_player_collision(w, &player)
    w.enemies[0] = Enemy{x = 64, y = 72, health = ENEMY_HEALTH, alive = true, facing = 1}
    w.enemy_count = 1
    testing.expect(t, !player_overlaps_enemy(player.x, player.y, &w.enemies[0]))
    update_player(&player, w, Input{jump_pressed = true, jump_held = true})
    testing.expect(t, player.y < 80)
    testing.expect(t, w.enemies[0].y < 72)
    testing.expect(t, !player_overlaps_enemy(player.x, player.y, &w.enemies[0]))
    for _ in 0..<8 {
        update_player(&player, w, Input{jump_held = true})
        update_enemies(w, &player)
        testing.expect(t, !player_overlaps_enemy(player.x, player.y, &w.enemies[0]))
    }
    testing.expect(t, player.y < 60 && w.enemies[0].y < 60)
}

@test
dragon_cannot_push_knight_through_ceiling :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    enemy_test_floor(w)
    player := Player{x = 60, y = 80, health = PLAYER_MAX_HEALTH}
    set_player_collision(w, &player)
    w.enemies[0] = Enemy{x = 64, y = 72, health = ENEMY_HEALTH, alive = true, facing = 1}
    w.enemy_count = 1
    place(w, 67, 71, .Stone)
    update_player(&player, w, Input{jump_pressed = true, jump_held = true})
    testing.expect(t, player.y == 80)
    testing.expect(t, w.enemies[0].y == 72)
}

@test
knight_reaches_player_across_barrel :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    enemy_test_floor(w)
    barrel := Barrel{x = 100, y = 76, material = .Snow}
    place_barrel(w, &barrel)
    player := Player{x = 45, y = 80, health = PLAYER_MAX_HEALTH}
    set_player_collision(w, &player)
    w.enemies[0] = Enemy{x = 140, y = 89, health = ENEMY_HEALTH, facing = -1,
                         alive = true, grounded = true, alert_time = 4}
    w.enemy_count = 1
    for _ in 0..<180 { update_enemies(w, &player) }
    testing.expect(t, w.enemies[0].x < barrel.x)
    testing.expect(t, !enemy_hits(w, w.enemies[0].x, w.enemies[0].y))
}

@test
knight_dies_into_falling_debris_after_hazard_damage :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    enemy_test_floor(w)
    player := Player{x = 200, y = 80, health = PLAYER_MAX_HEALTH}
    w.enemies[0] = Enemy{x = 60, y = 89, health = 8, alive = true}
    w.enemy_count = 1
    testing.expect(t, damage_enemy_from_projectile(w, 63, 93, .Boom))
    update_enemies(w, &player)
    testing.expect(t, !w.enemies[0].alive)
    debris_count := count_kind(w, .KnightDebris)
    body_pixels := 0
    for row := 0; row < ENEMY_H; row += 1 {
        for col := 0; col < ENEMY_W; col += 1 {
            if enemy_body_contains(col, row, 0, 0) { body_pixels += 1 }
        }
    }
    testing.expect(t, body_pixels == KNIGHT_BODY_PIXELS)
    testing.expect(t, debris_count == body_pixels/2)
    testing.expect(t, count_kind(w, .Blood) == body_pixels/2)
    scattered := 0
    for cell in w.cells {
        if (cell.kind == .KnightDebris || cell.kind == .Blood) && cell.scatter_ticks > 0 { scattered += 1 }
    }
    testing.expect(t, scattered == body_pixels)
    for _ in 0..<20 { step_world(w) }
    testing.expect(t, count_kind(w, .KnightDebris)+count_kind(w, .Blood) == body_pixels)
    for _ in 0..<260 { step_world(w) }
    testing.expect(t, count_kind(w, .KnightDebris) == 0)
    testing.expect(t, count_kind(w, .Blood) == 0)
}

@test
knight_debris_stacks_in_a_narrow_shaft_like_powder :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    for y := 85; y <= 100; y += 1 {
        place(w, 59, y, .Stone)
        place(w, 61, y, .Stone)
    }
    place(w, 60, 100, .Stone)
    place(w, 60, 89, .KnightDebris)
    place(w, 60, 90, .KnightDebris)
    for _ in 0..<35 { step_world(w) }
    testing.expect(t, kind_at(w, 60, 98) == .KnightDebris)
    testing.expect(t, kind_at(w, 60, 99) == .KnightDebris)
    testing.expect(t, count_kind(w, .KnightDebris) == 2)
}

@test
ogre_moves_at_half_knight_speed_and_has_five_times_health :: proc(t: ^testing.T) {
    testing.expect(t, enemy_run_speed(.Ogre) == enemy_run_speed(.Knight)/2)
    testing.expect(t, enemy_max_health(.Ogre) == enemy_max_health(.Knight)*5)
    knight_world := new(World)
    defer free(knight_world)
    ogre_world := new(World)
    defer free(ogre_world)
    enemy_test_floor(knight_world)
    enemy_test_floor(ogre_world)
    knight_player := Player{x = 50, y = 80, health = PLAYER_MAX_HEALTH}
    ogre_player := knight_player
    set_player_collision(knight_world, &knight_player)
    set_player_collision(ogre_world, &ogre_player)
    knight_world.enemies[0] = Enemy{kind = .Knight, x = 180, y = 89, health = ENEMY_HEALTH,
                         facing = -1, alive = true, grounded = true, alert_time = 4}
    ogre_world.enemies[0] = Enemy{kind = .Ogre, x = 180, y = 87, health = OGRE_HEALTH,
                         facing = -1, alive = true, grounded = true, alert_time = 4}
    knight_world.enemy_count = 1
    ogre_world.enemy_count = 1
    for _ in 0..<30 {
        update_enemies(knight_world, &knight_player)
        update_enemies(ogre_world, &ogre_player)
    }
    testing.expect(t, knight_world.enemies[0].x < ogre_world.enemies[0].x)
}

@test
ogre_attack_removes_thirty_health :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    enemy_test_floor(w)
    player := Player{x = 60, y = 80, health = PLAYER_MAX_HEALTH}
    set_player_collision(w, &player)
    w.enemies[0] = Enemy{kind = .Ogre, x = 73, y = 87, health = OGRE_HEALTH,
                         facing = -1, alive = true, grounded = true, alert_time = 4}
    w.enemy_count = 1
    for _ in 0..<20 { update_enemies(w, &player) }
    testing.expect(t, player.health == 70)
}

@test
ogre_drops_twice_as_many_remains_as_knight :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    enemy_test_floor(w)
    player := Player{x = 200, y = 80, health = PLAYER_MAX_HEALTH}
    w.enemies[0] = Enemy{kind = .Ogre, x = 60, y = 87, health = 8, alive = true}
    w.enemy_count = 1
    testing.expect(t, damage_enemy_from_projectile(w, 63, 93, .Boom))
    update_enemies(w, &player)
    testing.expect(t, !w.enemies[0].alive)
    testing.expect(t, count_kind(w, .OgreDebris) == OGRE_DEBRIS_COUNT/2)
    testing.expect(t, count_kind(w, .Blood) == OGRE_DEBRIS_COUNT/2)
    testing.expect(t, OGRE_DEBRIS_COUNT == KNIGHT_BODY_PIXELS*2)
}

@test
barbarian_leaps_on_frame_ten_and_strikes_on_eleven :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    enemy_test_floor(w)
    player := Player{x = 60, y = 80, health = PLAYER_MAX_HEALTH}
    set_player_collision(w, &player)
    w.enemies[0] = Enemy{kind = .Barbarian, x = 130, y = 87, health = BARBARIAN_HEALTH,
                         facing = -1, alive = true, grounded = true, alert_time = 4}
    w.enemy_count = 1
    saw_flight, saw_impact := false, false
    for _ in 0..<75 {
        update_enemies(w, &player)
        if w.enemies[0].barbarian_phase == 1 { saw_flight = true }
        if w.enemies[0].barbarian_phase == 2 { saw_impact = true }
    }
    testing.expect(t, saw_flight && saw_impact)
    testing.expect(t, player.health == 70)
    testing.expect(t, enemy_max_health(.Barbarian) == 250)
}

@test
enemies_pass_through_then_separate :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    enemy_test_floor(w)
    player := Player{x = 220, y = 80, health = PLAYER_MAX_HEALTH}
    set_player_collision(w, &player)
    w.enemies[0] = Enemy{x = 100, y = 89, health = ENEMY_HEALTH, alive = true, grounded = true}
    w.enemies[1] = Enemy{x = 100, y = 89, health = ENEMY_HEALTH, alive = true, grounded = true}
    w.enemy_count = 2
    testing.expect(t, enemy_can_enter(w, 0, 101, 89, 0))
    for _ in 0..<12 { update_enemies(w, &player) }
    testing.expect(t, w.enemies[0].x+ENEMY_W <= w.enemies[1].x)
}

@test
stuck_enemy_retreats_before_jumping :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    enemy_test_floor(w)
    player := Player{x = 50, y = 80, health = PLAYER_MAX_HEALTH}
    set_player_collision(w, &player)
    w.enemies[0] = Enemy{x = 100, y = 89, health = ENEMY_HEALTH, facing = -1,
                         alive = true, grounded = true, alert_time = 4,
                         last_chase_x = 100, chase_still_time = 0.34}
    w.enemy_count = 1
    for _ in 0..<18 { update_enemies(w, &player) }
    testing.expect(t, w.enemies[0].x >= 104)
    testing.expect(t, w.enemies[0].vy < 0)
}

@test
boss_jumps_dashes_and_hits_with_sword :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    enemy_test_floor(w)
    player := Player{x = 50, y = 80, health = PLAYER_MAX_HEALTH}
    set_player_collision(w, &player)
    w.enemies[0] = Enemy{kind = .Boss, x = 200, y = 63, health = BOSS_HEALTH,
                         facing = -1, alive = true, grounded = true, alert_time = 4}
    w.enemy_count = 1
    saw_jump, saw_dash := false, false
    for _ in 0..<200 {
        update_enemies(w, &player)
        if !w.enemies[0].grounded { saw_jump = true }
        if w.enemies[0].boss_dash_timer > 0 { saw_dash = true }
        if player.health < PLAYER_MAX_HEALTH { break }
    }
    testing.expect(t, enemy_max_health(.Boss) == 5000)
    testing.expect(t, saw_jump && saw_dash)
    testing.expect(t, player.health == 80)
}

@test
dragon_flashes_and_bleeds_when_damaged :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    player := Player{x = 50, y = 80, health = PLAYER_MAX_HEALTH}
    set_player_collision(w, &player)
    damage_player(w, &player, 20)
    testing.expect(t, player.health == 80)
    testing.expect(t, player.hurt_time == 1.0)
    testing.expect(t, count_kind(w, .Blood) > 0)
}
