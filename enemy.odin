package main

import rl "vendor:raylib"
import "core:c"

MAX_ENEMIES :: 40
ENEMY_W :: 8
ENEMY_H :: 11
ENEMY_HEALTH :: 100
OGRE_W :: 10
OGRE_H :: 13
OGRE_HEALTH :: ENEMY_HEALTH*5
BARBARIAN_W :: 10
BARBARIAN_H :: 13
BARBARIAN_HEALTH :: 250
BARBARIAN_DEBRIS_COUNT :: 96
BARBARIAN_STANDOFF :: 62
BARBARIAN_LUNGE_SPEED :: f32(520)
BOSS_W :: 20
BOSS_H :: 37
BOSS_HEALTH :: 5000
BOSS_RUN_SPEED :: f32(190)
BOSS_ATTACK_RANGE :: 62
BOSS_JUMP_SPEED :: f32(-480)
BOSS_DASH_SPEED :: f32(440)
BOSS_DEBRIS_COUNT :: 220
KNIGHT_BODY_PIXELS :: 72
ENEMY_SIGHT_RANGE :: 155
ENEMY_ATTACK_RANGE :: 19
ENEMY_ATTACK_DAMAGE :: 10
OGRE_ATTACK_DAMAGE :: 30
ENEMY_RUN_SPEED :: f32(94)
OGRE_RUN_SPEED :: ENEMY_RUN_SPEED/2
ENEMY_JUMP_SPEED :: f32(-390)
ENEMY_GRAVITY :: f32(1000)
ENEMY_ATTACK_FRAME_TIME :: f32(0.065)
ENEMY_ATTACK_FRAMES :: 13
ENEMY_DEBRIS_PER_PIXEL :: 1
OGRE_DEBRIS_COUNT :: KNIGHT_BODY_PIXELS*2

EnemyKind :: enum { Knight, Ogre, Barbarian, Boss }

// The body of knight_blue_idle_01.png (source x=1..8, y=4..14).
// Sword pixels are excluded so fluids can touch the armor closely.
ENEMY_BODY_MASK := [ENEMY_H]u8{
    0x3c, 0x7e, 0x7e, 0x7f, 0xff, 0xff,
    0xff, 0xff, 0xfe, 0xfc, 0x6c,
}

OGRE_BODY_MASK := [OGRE_H]u16{
    0xf8, 0xfc, 0x1fe, 0x3ff, 0x1fe, 0x1ff, 0x3fe,
    0x3fe, 0x3fe, 0x1fc, 0x1dc, 0x1dc, 0xcc,
}

BARBARIAN_BODY_MASK := [BARBARIAN_H]u16{
    0x00f, 0x3df, 0x3ff, 0x3ff, 0x3ff, 0x3ff, 0x3ff,
    0x3fe, 0x0fc, 0x0fc, 0x0fc, 0x0fc, 0x06c,
}

// Alpha mask of Colour1 FreeKnight's first idle frame, cropped to its body.
BOSS_BODY_MASK := [BOSS_H]u32{
    0x1e00, 0x3f00, 0x3f00, 0x7f00, 0x7f00, 0x7f00, 0x3f80,
    0x3fc0, 0x7fe0, 0xfff0, 0xfff8, 0x1fffc, 0x1fffc, 0x1fffc,
    0x1fffe, 0x1fffe, 0x3ffee, 0x3ffc7, 0x3ffc7, 0x7ffe7,
    0x7ffe7, 0x7ffef, 0x7ffff, 0x7fff7, 0x3fbf6, 0xfbe0,
    0xf1e0, 0x1f1f0, 0x1f1f0, 0xf0f0, 0xf0f0, 0x70f0,
    0x7070, 0x7070, 0xf078, 0x3f07c, 0x3f07c,
}

Enemy :: struct {
    kind: EnemyKind,
    x, y: int,
    squad_id, flank_side, flank_rank: int,
    barbarian_phase, retreat_start_x, retreat_dir, last_chase_x: int,
    chase_still_time, retreat_timer, overlap_time: f32,
    boss_jump_cooldown, boss_dash_cooldown, boss_dash_timer: f32,
    vx, vy, remainder_x, remainder_y: f32,
    alert_time, attack_time, attack_cooldown, animation_time: f32,
    pending_damage, health: int,
    facing: int,
    alive, grounded, attacking, attack_landed: bool,
}

enemy_width :: proc(kind: EnemyKind) -> int { if kind == .Boss { return BOSS_W }; if kind == .Ogre { return OGRE_W }; if kind == .Barbarian { return BARBARIAN_W }; return ENEMY_W }
enemy_height :: proc(kind: EnemyKind) -> int { if kind == .Boss { return BOSS_H }; if kind == .Ogre { return OGRE_H }; if kind == .Barbarian { return BARBARIAN_H }; return ENEMY_H }
enemy_max_health :: proc(kind: EnemyKind) -> int { if kind == .Boss { return BOSS_HEALTH }; if kind == .Ogre { return OGRE_HEALTH }; if kind == .Barbarian { return BARBARIAN_HEALTH }; return ENEMY_HEALTH }
enemy_attack_damage :: proc(kind: EnemyKind) -> int { if kind == .Boss { return 20 }; if kind == .Ogre || kind == .Barbarian { return OGRE_ATTACK_DAMAGE }; return ENEMY_ATTACK_DAMAGE }
enemy_attack_damage_against :: proc(kind: EnemyKind, player: ^Player) -> int {
    if kind == .Boss && player.empowered { return 2 }
    return enemy_attack_damage(kind)
}
enemy_run_speed :: proc(kind: EnemyKind) -> f32 { if kind == .Boss { return BOSS_RUN_SPEED }; if kind == .Ogre { return OGRE_RUN_SPEED }; return ENEMY_RUN_SPEED }
enemy_attack_frames :: proc(kind: EnemyKind) -> int { if kind == .Boss { return 4 }; if kind == .Ogre { return 8 }; return ENEMY_ATTACK_FRAMES }
enemy_attack_hit_frame :: proc(kind: EnemyKind) -> int { if kind == .Boss { return 2 }; if kind == .Ogre { return 4 }; return 6 }

enemy_body_contains_kind :: proc(kind: EnemyKind, x, y, body_x, body_y: int) -> bool {
    dx, dy := x-body_x, y-body_y
    if dx < 0 || dx >= enemy_width(kind) || dy < 0 || dy >= enemy_height(kind) { return false }
    if kind == .Ogre { return OGRE_BODY_MASK[dy] & (u16(1) << u16(dx)) != 0 }
    if kind == .Barbarian { return BARBARIAN_BODY_MASK[dy] & (u16(1) << u16(dx)) != 0 }
    if kind == .Boss { return BOSS_BODY_MASK[dy] & (u32(1) << u32(dx)) != 0 }
    return ENEMY_BODY_MASK[dy] & (u8(1) << u8(dx)) != 0
}

enemy_body_contains :: proc(x, y, body_x, body_y: int) -> bool {
    return enemy_body_contains_kind(.Knight, x, y, body_x, body_y)
}

enemy_hits_kind :: proc(w: ^World, kind: EnemyKind, x, y: int) -> bool {
    for dy := 0; dy < enemy_height(kind); dy += 1 {
        for dx := 0; dx < enemy_width(kind); dx += 1 {
            px, py := x+dx, y+dy
            if !enemy_body_contains_kind(kind, px, py, x, y) { continue }
            if !inside(px, py) { return true }
            kind := kind_at(w, px, py)
            if solid(kind) || powder(kind) { return true }
        }
    }
    return false
}

enemy_hits :: proc(w: ^World, x, y: int) -> bool { return enemy_hits_kind(w, .Knight, x, y) }

enemy_can_enter :: proc(w: ^World, enemy_index, x, y, dy: int) -> bool {
    kind := w.enemies[enemy_index].kind
    for row := 0; row < enemy_height(kind); row += 1 {
        for col := 0; col < enemy_width(kind); col += 1 {
            px, py := x+col, y+row
            if !enemy_body_contains_kind(kind, px, py, x, y) { continue }
            // Enemies are allowed to pass through each other. Their spacing is
            // corrected after movement so a whole squad cannot form one pile.
            if !inside(px, py) || player_occupies(w, px, py) { return false }
            kind := kind_at(w, px, py)
            if solid(kind) || (dy > 0 && powder(kind)) { return false }
        }
    }
    for row := 0; row < enemy_height(kind); row += 1 {
        for col := 0; col < enemy_width(kind); col += 1 {
            px, py := x+col, y+row
            if !enemy_body_contains_kind(kind, px, py, x, y) { continue }
            kind := kind_at(w, px, py)
            if !mobile(kind) { continue }
            if !push_particle_out_body(w, px, py, x, y, .Knight, enemy_index) {
                if liquid(kind) || gas(kind) { continue }
                return false
            }
        }
    }
    return true
}

// A dragon jumping into the knight from below carries it upward one cell.
// Collision checks still stop both actors at a real ceiling.
lift_enemy_one_cell :: proc(w: ^World, enemy_index: int) -> bool {
    enemy := &w.enemies[enemy_index]
    if !enemy.alive || !enemy_can_enter(w, enemy_index, enemy.x, enemy.y-1, -1) { return false }
    old_y := enemy.y
    enemy.y -= 1
    enemy.grounded = false
    enemy.vy = min(enemy.vy, 0)
    enemy.remainder_y = 0
    for y := old_y; y < old_y+enemy_height(enemy.kind); y += 1 {
        for x := enemy.x; x < enemy.x+enemy_width(enemy.kind); x += 1 {
            if enemy_body_contains_kind(enemy.kind, x, y, enemy.x, old_y) &&
               !enemy_body_contains_kind(enemy.kind, x, y, enemy.x, enemy.y) { wake_neighbors(w, x, y) }
        }
    }
    return true
}

enemy_can_see_player :: proc(w: ^World, enemy: ^Enemy, player: ^Player) -> bool {
    start_x, start_y := enemy.x+enemy_width(enemy.kind)/2, enemy.y+3
    end_x, end_y := player.x+PLAYER_W/2, player.y+7
    dx, dy := end_x-start_x, end_y-start_y
    sight := ENEMY_SIGHT_RANGE
    if enemy.kind == .Boss { sight = 270 }
    if abs(dx) > sight || abs(dy) > 55 { return false }
    steps := max(abs(dx), abs(dy))
    if steps == 0 { return true }
    for step := 2; step < steps-2; step += 2 {
        px := start_x+dx*step/steps
        py := start_y+dy*step/steps
        if solid(kind_at(w, px, py)) { return false }
    }
    return true
}

spawn_level_enemies :: proc(w: ^World, level: ^Level, seed: ^u32) {
    spawn_enemy_near(w, level, WORLD_W-150, .Boss, 0, 0, 0)
    x := CAVE_EXIT_X+115+int(level_random(seed)%55)
    squad_id := 1
    for x < WORLD_W-430 && w.enemy_count < MAX_ENEMIES-5 {
        group_size := 2+int(level_random(seed)%4)
        for member := 0; member < group_size; member += 1 {
            side := -1
            if member%2 == 1 { side = 1 }
            rank := member/2
            spawn_enemy_near(w, level, x+member*13, .Knight, squad_id, side, rank)
        }
        if squad_id%3 == 0 { spawn_enemy_near(w, level, x+group_size*13+10, .Ogre, 0, 0, 0) }
        if squad_id%2 == 0 { spawn_enemy_near(w, level, x+group_size*13+25, .Barbarian, 0, 0, 0) }
        squad_id += 1
        x += 195+int(level_random(seed)%65)
    }
}

spawn_enemy_near :: proc(w: ^World, level: ^Level, target_x: int,
                        kind: EnemyKind, squad_id, flank_side, flank_rank: int) -> bool {
    if w.enemy_count >= MAX_ENEMIES { return false }
    signs := [2]int{1, -1}
    for radius := 0; radius < 85; radius += 1 {
        for sign in signs {
            spawn_x := target_x+sign*radius
            if spawn_x < 120 || spawn_x >= WORLD_W-enemy_width(kind) { continue }
            spawn_y := level.terrain[spawn_x]-enemy_height(kind)
            if enemy_hits_kind(w, kind, spawn_x, spawn_y) { continue }
            for spawn_y < WORLD_H-enemy_height(kind)-1 &&
                !enemy_hits_kind(w, kind, spawn_x, spawn_y+1) {
                spawn_y += 1
            }
            if !enemy_hits_kind(w, kind, spawn_x, spawn_y+1) { continue }
            occupied := false
            for i := 0; i < w.enemy_count; i += 1 {
                other := &w.enemies[i]
                if abs(spawn_x-other.x) < enemy_width(kind)+2 &&
                   abs(spawn_y-other.y) < max(enemy_height(kind), enemy_height(other.kind)) {
                    occupied = true
                    break
                }
            }
            if occupied { continue }
            w.enemies[w.enemy_count] = Enemy{
                kind = kind, x = spawn_x, y = spawn_y,
                squad_id = squad_id, flank_side = flank_side, flank_rank = flank_rank,
                health = enemy_max_health(kind), facing = -1,
                alive = true, grounded = true,
            }
            w.enemy_count += 1
            return true
        }
    }
    return false
}

damage_enemy_from_projectile :: proc(w: ^World, x, y: int, material: Material, empowered := false) -> bool {
    i := enemy_at(w, x, y)
    if i < 0 { return false }
    enemy := &w.enemies[i]
    if enemy.kind == .Boss && w.boss_locked { return true }
    #partial switch material {
    case .Fire: enemy.pending_damage += (empowered ? 8 : 2)
    case .Acid: enemy.pending_damage += 4
    case .Lava: enemy.pending_damage += 6
    case .Boom: enemy.pending_damage += 40
    case .Plasma: enemy.pending_damage += 5
    }
    enemy.alert_time = 4
    return true
}

enemy_contact_damage :: proc(w: ^World, enemy: ^Enemy) -> int {
    damage := 0
    for y := enemy.y-1; y <= enemy.y+enemy_height(enemy.kind); y += 1 {
        for x := enemy.x-1; x <= enemy.x+enemy_width(enemy.kind); x += 1 {
            if !inside(x, y) { continue }
            kind := kind_at(w, x, y)
            #partial switch kind {
            case .Fire: damage = max(damage, 2)
            case .Acid: damage = max(damage, 4)
            case .Lava: damage = max(damage, 6)
            case .Boom: damage = max(damage, 35)
            case .Plasma: damage = max(damage, 5)
            }
        }
    }
    return damage
}

spawn_enemy_debris :: proc(w: ^World, enemy: ^Enemy) {
    sources: [BOSS_W*BOSS_H][2]int
    source_count := 0
    for row := 0; row < enemy_height(enemy.kind); row += 1 {
        for col := 0; col < enemy_width(enemy.kind); col += 1 {
            if !enemy_body_contains_kind(enemy.kind, enemy.x+col, enemy.y+row, enemy.x, enemy.y) { continue }
            sources[source_count] = {enemy.x+col, enemy.y+row}
            source_count += 1
        }
    }
    debris_count := source_count*ENEMY_DEBRIS_PER_PIXEL
    debris_kind := Material.KnightDebris
    if enemy.kind == .Ogre {
        debris_count = OGRE_DEBRIS_COUNT
        debris_kind = .OgreDebris
    } else if enemy.kind == .Barbarian {
        debris_count = BARBARIAN_DEBRIS_COUNT
    } else if enemy.kind == .Boss {
        debris_count = BOSS_DEBRIS_COUNT
    }
    for n := 0; n < debris_count; n += 1 {
        source := sources[n%source_count]
        source_x, source_y := source[0], source[1]
        shade := u8(rand(w)%4)
        flip_x := rand(w)&1 != 0
        flip_y := rand(w)&1 != 0
        placed := false
        start_radius := 3+int(rand(w)%6)
        for radius := start_radius; radius <= 24 && !placed; radius += 1 {
            for raw_dy := -radius; raw_dy <= radius && !placed; raw_dy += 1 {
                dy := raw_dy
                if flip_y { dy = -dy }
                for raw_dx := -radius; raw_dx <= radius; raw_dx += 1 {
                    dx := raw_dx
                    if flip_x { dx = -dx }
                    if max(abs(dx), abs(dy)) != radius { continue }
                    x, y := source_x+dx, source_y+dy
                    if !inside(x, y) || kind_at(w, x, y) != .Empty || actor_occupies(w, x, y) { continue }
                    material := debris_kind
                    if n%2 == 1 { material = .Blood }
                    place(w, x, y, material)
                    w.cells[index(x, y)].shade = shade
                    direction := 1
                    if x < enemy.x+enemy_width(enemy.kind)/2 { direction = -1 }
                    w.cells[index(x, y)].vx = f32(direction)*(1.4+f32(rand(w)%190)/100)
                    w.cells[index(x, y)].vy = -1.8-f32(rand(w)%220)/100
                    w.cells[index(x, y)].scatter_ticks = u8(10+rand(w)%9)
                    placed = true
                    break
                }
            }
        }
    }
}

enemy_try_step_up :: proc(w: ^World, enemy_index, direction: int) -> bool {
    enemy := &w.enemies[enemy_index]
    if !enemy.grounded { return false }
    for rise := 1; rise <= MAX_STEP_HEIGHT; rise += 1 {
        if enemy_hits_kind(w, enemy.kind, enemy.x, enemy.y-rise) { break }
        if enemy_can_enter(w, enemy_index, enemy.x+direction, enemy.y-rise, 0) {
            enemy.x += direction
            enemy.y -= rise
            enemy.vy, enemy.remainder_y = 0, 0
            return true
        }
    }
    return false
}

enemy_tall_obstacle_ahead :: proc(w: ^World, enemy: ^Enemy, direction: int) -> bool {
    if direction == 0 { return false }
    front_x := enemy.x-1
    if direction > 0 { front_x = enemy.x+enemy_width(enemy.kind) }
    for distance := 0; distance < 9; distance += 1 {
        x := front_x+distance*direction
        if x < 0 || x >= WORLD_W { return false }
        for y := enemy.y; y < enemy.y+enemy_height(enemy.kind)-MAX_STEP_HEIGHT; y += 1 {
            if solid(kind_at(w, x, y)) { return true }
        }
    }
    return false
}

update_enemy :: proc(w: ^World, enemy_index: int, player: ^Player) {
    enemy := &w.enemies[enemy_index]
    if !enemy.alive { return }
    if enemy.kind == .Boss && w.boss_locked {
        enemy.pending_damage = 0
        enemy.vx, enemy.vy = 0, 0
        return
    }
    damage := min(8, enemy.pending_damage)+enemy_contact_damage(w, enemy)
    enemy.pending_damage = 0
    if damage > 0 {
        enemy.health -= damage
        // The first duel leads to the dragon's transformation. The boss can
        // be wounded, but the finishing blow belongs to the second phase.
        if enemy.kind == .Boss && !player.empowered {
            enemy.health = max(enemy.health, BOSS_HEALTH/2)
        }
        enemy.alert_time = 4
        if enemy.health <= 0 {
            enemy.alive = false
            spawn_enemy_debris(w, enemy)
            for y := enemy.y; y < enemy.y+enemy_height(enemy.kind); y += 1 {
                for x := enemy.x; x < enemy.x+enemy_width(enemy.kind); x += 1 { wake_neighbors(w, x, y) }
            }
            return
        }
    }

    enemy.animation_time += PHYSICS_DT
    if enemy.attack_cooldown > 0 { enemy.attack_cooldown -= PHYSICS_DT }
    if enemy.boss_jump_cooldown > 0 { enemy.boss_jump_cooldown -= PHYSICS_DT }
    if enemy.boss_dash_cooldown > 0 { enemy.boss_dash_cooldown -= PHYSICS_DT }
    if enemy_can_see_player(w, enemy, player) { enemy.alert_time = 4 }
    if enemy.alert_time > 0 { enemy.alert_time -= PHYSICS_DT }

    dx := player.x+PLAYER_W/2-enemy.x-enemy_width(enemy.kind)/2
    dy := player.y+PLAYER_H/2-enemy.y-enemy_height(enemy.kind)/2
    on_flank := enemy.squad_id == 0 ||
                enemy.flank_side*(enemy.x+enemy_width(enemy.kind)/2-player.x-PLAYER_W/2) >= 6
    chase_distance := 25
    if enemy.kind == .Barbarian { chase_distance = BARBARIAN_STANDOFF+8 }
    if !enemy.attacking && enemy.alert_time > 0 && enemy.retreat_timer <= 0 && abs(dx) > chase_distance {
        if abs(enemy.x-enemy.last_chase_x) <= 1 { enemy.chase_still_time += PHYSICS_DT }
        else { enemy.chase_still_time = 0; enemy.last_chase_x = enemy.x }
        if enemy.chase_still_time >= 0.35 {
            enemy.retreat_dir = 1
            if dx > 0 { enemy.retreat_dir = -1 }
            enemy.retreat_start_x = enemy.x
            enemy.retreat_timer = 0.28
            enemy.chase_still_time = 0
        }
    } else if enemy.retreat_timer <= 0 {
        enemy.chase_still_time = 0
        enemy.last_chase_x = enemy.x
    }
    if enemy.attacking {
        if enemy.kind == .Barbarian {
            enemy.attack_time += PHYSICS_DT
            if enemy.barbarian_phase == 0 {
                enemy.vx = approach(enemy.vx, 0, 1500*PHYSICS_DT)
                if enemy.attack_time >= 9*ENEMY_ATTACK_FRAME_TIME {
                    enemy.barbarian_phase = 1 // frame 10: flight
                    enemy.attack_time = 0
                    enemy.vx = f32(enemy.facing)*BARBARIAN_LUNGE_SPEED
                    enemy.vy = -100
                    enemy.grounded = false
                }
            } else if enemy.barbarian_phase == 1 {
                enemy.vx = f32(enemy.facing)*BARBARIAN_LUNGE_SPEED
                enemy.vy = f32(clamp(dy*18, -200, 210))
                if abs(dx) <= ENEMY_ATTACK_RANGE && abs(dy) <= 18 {
                    enemy.barbarian_phase = 2 // frame 11: impact
                    enemy.attack_time = 0
                    enemy.vx = 0
                    if !enemy.attack_landed {
                        damage_player(w, player, 30)
                        enemy.attack_landed = true
                    }
                } else if enemy.attack_time >= 0.30 {
                    enemy.barbarian_phase = 2
                    enemy.attack_time = 0
                    enemy.vx = 0
                }
            } else {
                enemy.vx = approach(enemy.vx, 0, 1500*PHYSICS_DT)
                if enemy.attack_time >= 3*ENEMY_ATTACK_FRAME_TIME {
                    enemy.attacking = false
                    enemy.attack_cooldown = 0.55
                    enemy.attack_time = 0
                }
            }
        } else {
            enemy.attack_time += PHYSICS_DT
            enemy.vx = approach(enemy.vx, 0, 1500*PHYSICS_DT)
            if !enemy.attack_landed && enemy.attack_time >= ENEMY_ATTACK_FRAME_TIME*f32(enemy_attack_hit_frame(enemy.kind)) {
                enemy.attack_landed = true
                in_front := dx*enemy.facing >= -2
                reach := ENEMY_ATTACK_RANGE
                height := 17
                if enemy.kind == .Boss { reach, height = BOSS_ATTACK_RANGE, 30 }
                if in_front && abs(dx) <= reach && abs(dy) <= height {
                    damage_player(w, player, enemy_attack_damage_against(enemy.kind, player))
                }
            }
            if enemy.attack_time >= ENEMY_ATTACK_FRAME_TIME*f32(enemy_attack_frames(enemy.kind)) {
                enemy.attacking = false
                enemy.attack_cooldown = 0.35
                if enemy.kind == .Boss { enemy.attack_cooldown = 0.65 }
                enemy.attack_time = 0
            }
        }
    } else if enemy.alert_time > 0 && enemy.attack_cooldown <= 0 && enemy.retreat_timer <= 0 && on_flank &&
              ((enemy.kind == .Barbarian && abs(dx) <= BARBARIAN_STANDOFF+8) ||
               (enemy.kind == .Boss && abs(dx) <= BOSS_ATTACK_RANGE) ||
               (enemy.kind != .Barbarian && enemy.kind != .Boss && abs(dx) <= ENEMY_ATTACK_RANGE-3)) &&
              abs(dy) <= (enemy.kind == .Boss ? 30 : 16) &&
              enemy_can_see_player(w, enemy, player) {
        enemy.attacking = true
        enemy.attack_landed = false
        enemy.attack_time = 0
        enemy.animation_time = 0
        enemy.barbarian_phase = 0
        enemy.facing = 1
        if dx < 0 { enemy.facing = -1 }
        enemy.vx = 0
    } else {
        direction := 0
        target_dx := dx
        if enemy.kind == .Knight && enemy.squad_id > 0 {
            target_dx += enemy.flank_side*(15+enemy.flank_rank*11)
        }
        if enemy.kind == .Barbarian && abs(dx) <= BARBARIAN_STANDOFF { target_dx = 0 }
        if enemy.alert_time > 0 && abs(target_dx) > 5 {
            if target_dx < 0 { direction = -1 } else { direction = 1 }
        }
        if enemy.retreat_timer > 0 { direction = enemy.retreat_dir }
        if direction != 0 { enemy.facing = direction }
        enemy.vx = approach(enemy.vx, f32(direction)*enemy_run_speed(enemy.kind), 800*PHYSICS_DT)
        should_jump := dy < -16 && abs(dx) < 30
        // The far-side knight hops past the dragon instead of piling up behind allies.
        if enemy.kind == .Knight && enemy.squad_id > 0 &&
           enemy.flank_side*(enemy.x+ENEMY_W/2-player.x-PLAYER_W/2) < 0 && abs(dx) < 38 {
            should_jump = true
        }
        if enemy_tall_obstacle_ahead(w, enemy, direction) { should_jump = true }
        if enemy.kind == .Boss && enemy.boss_jump_cooldown <= 0 &&
           abs(dx) > BOSS_ATTACK_RANGE && abs(dx) < 165 { should_jump = true }
        if enemy.grounded && enemy.alert_time > 0 && should_jump {
            enemy.vy = ENEMY_JUMP_SPEED
            if enemy.kind == .Boss {
                enemy.vy = BOSS_JUMP_SPEED
                enemy.boss_jump_cooldown = 1.8
            }
            enemy.grounded = false
        }
    }

    if enemy.kind == .Boss && !enemy.attacking && enemy.alert_time > 0 && !enemy.grounded &&
       enemy.boss_dash_timer <= 0 && enemy.boss_dash_cooldown <= 0 && abs(dx) < 175 {
        enemy.boss_dash_timer = 0.17
        enemy.boss_dash_cooldown = 1.9
        enemy.facing = 1
        if dx < 0 { enemy.facing = -1 }
    }
    if enemy.kind == .Boss && enemy.boss_dash_timer > 0 {
        enemy.vx = f32(enemy.facing)*BOSS_DASH_SPEED
        enemy.boss_dash_timer -= PHYSICS_DT
    }

    enemy.remainder_x += enemy.vx*PHYSICS_DT
    move_x := int(enemy.remainder_x)
    enemy.remainder_x -= f32(move_x)
    step_x := 1
    if move_x < 0 { step_x = -1; move_x = -move_x }
    for _ in 0..<move_x {
        if enemy_can_enter(w, enemy_index, enemy.x+step_x, enemy.y, 0) {
            enemy.x += step_x
        } else if enemy_try_step_up(w, enemy_index, step_x) {
            continue
        } else {
            if enemy.grounded && !enemy.attacking && enemy.alert_time > 0 && enemy.retreat_timer <= 0 {
                enemy.vy = ENEMY_JUMP_SPEED
                if enemy.kind == .Boss { enemy.vy = BOSS_JUMP_SPEED }
                enemy.grounded = false
            }
            enemy.vx, enemy.remainder_x = 0, 0
            break
        }
    }

    if !enemy.grounded { enemy.vy = min(TERMINAL_VELOCITY, enemy.vy+ENEMY_GRAVITY*PHYSICS_DT) }
    enemy.remainder_y += enemy.vy*PHYSICS_DT
    move_y := int(enemy.remainder_y)
    enemy.remainder_y -= f32(move_y)
    step_y := 1
    if move_y < 0 { step_y = -1; move_y = -move_y }
    for _ in 0..<move_y {
        if enemy_can_enter(w, enemy_index, enemy.x, enemy.y+step_y, step_y) {
            enemy.y += step_y
        } else {
            enemy.vy, enemy.remainder_y = 0, 0
            break
        }
    }
    enemy.grounded = enemy_hits_kind(w, enemy.kind, enemy.x, enemy.y+1)
    if enemy.grounded && enemy.vy > 0 { enemy.vy = 0 }
    if enemy.retreat_timer > 0 {
        enemy.retreat_timer -= PHYSICS_DT
        if enemy.retreat_timer <= 0 {
            // The takeoff occurs after backing away, from the new position.
            if abs(enemy.x-enemy.retreat_start_x) >= 4 {
                enemy.vy = ENEMY_JUMP_SPEED
                enemy.grounded = false
            } else {
                enemy.retreat_dir = -enemy.retreat_dir
                enemy.retreat_start_x = enemy.x
                enemy.retreat_timer = 0.28
            }
            enemy.last_chase_x = enemy.x
        }
    }
    if enemy.y >= WORLD_H { enemy.alive = false }
}

update_enemies :: proc(w: ^World, player: ^Player) {
    // One spotter alerts the entire squad, including knights behind a house.
    for i := 0; i < w.enemy_count; i += 1 {
        spotter := &w.enemies[i]
        if !spotter.alive || spotter.squad_id == 0 || !enemy_can_see_player(w, spotter, player) { continue }
        for j := 0; j < w.enemy_count; j += 1 {
            if w.enemies[j].alive && w.enemies[j].squad_id == spotter.squad_id {
                w.enemies[j].alert_time = 4
            }
        }
    }
    for i := 0; i < w.enemy_count; i += 1 { update_enemy(w, i, player) }
    overlaps: [MAX_ENEMIES]bool
    for i := 0; i < w.enemy_count; i += 1 {
        first := &w.enemies[i]
        if !first.alive { continue }
        for j := i+1; j < w.enemy_count; j += 1 {
            second := &w.enemies[j]
            if !second.alive ||
               first.x+enemy_width(first.kind) <= second.x ||
               second.x+enemy_width(second.kind) <= first.x ||
               first.y+enemy_height(first.kind) <= second.y ||
               second.y+enemy_height(second.kind) <= first.y { continue }
            overlaps[i], overlaps[j] = true, true
            first_dir, second_dir := -1, 1
            if first.x+enemy_width(first.kind)/2 > second.x+enemy_width(second.kind)/2 {
                first_dir, second_dir = 1, -1
            }
            pressure := 1+min(2, int(max(first.overlap_time, second.overlap_time)/0.12))
            for _ in 0..<pressure {
                if enemy_can_enter(w, i, first.x+first_dir, first.y, 0) { first.x += first_dir }
                if enemy_can_enter(w, j, second.x+second_dir, second.y, 0) { second.x += second_dir }
            }
        }
    }
    for i := 0; i < w.enemy_count; i += 1 {
        if overlaps[i] { w.enemies[i].overlap_time += PHYSICS_DT }
        else { w.enemies[i].overlap_time = 0 }
    }
}

draw_enemies :: proc(w: ^World, knight_sprite, ogre_sprite, barbarian_sprite, boss_sprite: rl.Texture2D,
                     camera_px_x, camera_px_y: int) {
    for i := 0; i < w.enemy_count; i += 1 {
        enemy := &w.enemies[i]
        if !enemy.alive { continue }
        sprite := knight_sprite
        frame_size, run_frames, attack_start := 20, 8, 12
        frame_height := frame_size
        draw_x := enemy.x-1
        draw_y := enemy.y-8
        if enemy.kind == .Ogre {
            sprite = ogre_sprite
            frame_size, run_frames, attack_start = 22, 4, 8
            draw_x = enemy.x-2
        } else if enemy.kind == .Barbarian {
            sprite = barbarian_sprite
            frame_size, run_frames, attack_start = 20, 4, 8
            draw_x = enemy.x-2
            draw_y = enemy.y-6
        } else if enemy.kind == .Boss {
            sprite = boss_sprite
            frame_size, frame_height, run_frames, attack_start = 120, 80, 10, 20
            draw_x, draw_y = enemy.x-45, enemy.y-43
        }
        frame := 0
        if enemy.attacking {
            if enemy.kind == .Barbarian {
                if enemy.barbarian_phase == 0 {
                    frame = attack_start+min(8, int(enemy.attack_time/ENEMY_ATTACK_FRAME_TIME))
                } else if enemy.barbarian_phase == 1 {
                    frame = attack_start+9
                } else {
                    frame = attack_start+10+min(2, int(enemy.attack_time/ENEMY_ATTACK_FRAME_TIME))
                }
            } else {
                frame = attack_start+min(enemy_attack_frames(enemy.kind)-1, int(enemy.attack_time/ENEMY_ATTACK_FRAME_TIME))
            }
        } else if enemy.vx > 8 || enemy.vx < -8 {
            frame = 4+int(enemy.animation_time/0.09)%run_frames
        } else {
            frame = int(enemy.animation_time/0.16)%4
        }
        if enemy.kind == .Boss {
            if enemy.attacking {
                frame = 20+min(3, int(enemy.attack_time/ENEMY_ATTACK_FRAME_TIME))
            } else if enemy.boss_dash_timer > 0 {
                frame = 30+int(enemy.animation_time/0.06)%2
            } else if !enemy.grounded {
                frame = 24+int(enemy.animation_time/0.10)%3
                if enemy.vy >= 0 { frame = 27+int(enemy.animation_time/0.10)%3 }
            } else if abs(enemy.vx) > 8 {
                frame = 10+int(enemy.animation_time/0.07)%10
            } else {
                frame = int(enemy.animation_time/0.12)%10
            }
        }
        if rl.IsTextureValid(sprite) {
            source := rl.Rectangle{f32(frame*frame_size), 0, f32(frame_size), f32(frame_height)}
            if enemy.facing < 0 {
                source.width = -f32(frame_size)
                if enemy.kind == .Boss { draw_x -= 11 } else { draw_x -= 10 }
            }
            destination := rl.Rectangle{
                f32(draw_x*CELL_SIZE-camera_px_x),
                f32(draw_y*CELL_SIZE-camera_px_y),
                f32(frame_size*CELL_SIZE), f32(frame_height*CELL_SIZE),
            }
            rl.DrawTexturePro(sprite, source, destination, rl.Vector2{}, 0, rl.WHITE)
        }
        bar_width := 42
        if enemy.kind == .Boss { bar_width = 160 }
        bar_x := (enemy.x+enemy_width(enemy.kind)/2)*CELL_SIZE-camera_px_x-bar_width/2
        bar_y := (enemy.y-11)*CELL_SIZE-camera_px_y
        if enemy.kind == .Boss { bar_y = (enemy.y-17)*CELL_SIZE-camera_px_y }
        rl.DrawRectangle(c.int(bar_x), c.int(bar_y), c.int(bar_width), 10, rl.Color{17, 19, 28, 235})
        fill := bar_width*max(0, enemy.health)/enemy_max_health(enemy.kind)
        color := rl.Color{73, 190, 91, 255}
        if enemy.health*3 < enemy_max_health(enemy.kind) { color = rl.Color{217, 72, 62, 255} }
        rl.DrawRectangle(c.int(bar_x+1), c.int(bar_y+1), c.int(max(0, fill-2)), 8, color)
        hp_text := rl.TextFormat("%d", max(0, enemy.health))
        text_width := int(rl.MeasureText(hp_text, 9))
        rl.DrawText(hp_text, c.int(bar_x+(bar_width-text_width)/2), c.int(bar_y), 9, rl.WHITE)
    }
}
