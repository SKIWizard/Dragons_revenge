package main

import "core:testing"

@test
boss_does_not_move_before_dialogue :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    for x := 0; x < 260; x += 1 { place(w, x, 100, .Stone) }
    player := Player{x = 80, y = 80, health = PLAYER_MAX_HEALTH}
    w.enemies[0] = Enemy{kind = .Boss, x = 160, y = 63, health = BOSS_HEALTH,
                         facing = -1, alive = true, grounded = true}
    w.enemy_count = 1
    w.boss_locked = true
    testing.expect(t, boss_in_view(w, 0))
    for _ in 0..<90 { update_enemies(w, &player) }
    testing.expect(t, w.enemies[0].x == 160)
    testing.expect(t, w.enemies[0].health == BOSS_HEALTH)
    testing.expect(t, !boss_is_defeated(w))
}

@test
boss_survives_first_duel_until_dragon_transforms :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    player := Player{x = 10, y = 80, health = PLAYER_MAX_HEALTH}
    w.enemies[0] = Enemy{kind = .Boss, x = 200, y = 60, health = BOSS_HEALTH/2+1,
                         pending_damage = 40, facing = -1, alive = true}
    w.enemy_count = 1
    update_enemy(w, 0, &player)
    testing.expect(t, w.enemies[0].alive)
    testing.expect(t, w.enemies[0].health == BOSS_HEALTH/2)
    player.empowered = true
    w.enemies[0].health = 1
    w.enemies[0].pending_damage = 8
    update_enemy(w, 0, &player)
    testing.expect(t, boss_is_defeated(w))
}

@test
boss_defeat_transforms_once_and_reduces_sword_damage :: proc(t: ^testing.T) {
    testing.expect(t, dialogue_total(.BossQuestion) == 26)
    testing.expect(t, dialogue_total(.BossAnswer) == 34)
    testing.expect(t, dialogue_total(.BossDefiance) == 30)
    testing.expect(t, dialogue_total(.BossFarewell) == 23)
    player := Player{health = 0}
    testing.expect(t, boss_transformation_ready(.Fighting, player.health))
    testing.expect(t, !boss_transformation_ready(.Waiting, player.health))
    testing.expect(t, !boss_transformation_ready(.Empowered, player.health))
    testing.expect(t, enemy_attack_damage_against(.Boss, &player) == 20)
    player.empowered = true
    player.health = PLAYER_MAX_HEALTH
    testing.expect(t, enemy_attack_damage_against(.Boss, &player) == 2)
    testing.expect(t, enemy_attack_damage_against(.Knight, &player) == 10)
}

@test
empowered_fire_damages_boss_faster :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    w.enemies[0] = Enemy{kind = .Boss, x = 40, y = 50, health = BOSS_HEALTH, alive = true}
    w.enemy_count = 1
    w.boss_locked = false
    // The centre of the boss's 20x37 mask is occupied.
    testing.expect(t, damage_enemy_from_projectile(w, 50, 65, .Fire))
    testing.expect(t, w.enemies[0].pending_damage == 2)
    testing.expect(t, damage_enemy_from_projectile(w, 50, 65, .Fire, true))
    testing.expect(t, w.enemies[0].pending_damage == 10)
}
