package main

import "core:testing"

@test
intro_cave_gate_and_barrel_are_playable :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    level := new(Level)
    defer free(level)
    w.random_state = 1
    generate_level(w, level, 17)
    testing.expect(t, kind_at(w, INTRO_EGG_X, FLOOR_Y-1) == .Empty)
    testing.expect(t, kind_at(w, INTRO_EGG_X, FLOOR_Y) == .Stone)
    testing.expect(t, kind_at(w, INTRO_EGG_X, intro_roof(INTRO_EGG_X)) == .Stone)
    for y := intro_roof(INTRO_GATE_X)+1; y < level.terrain[INTRO_GATE_X]; y += 1 {
        testing.expect(t, kind_at(w, INTRO_GATE_X, y) == .Wood)
    }
    testing.expect(t, level.barrels[0].x == INTRO_BARREL_X)
    testing.expect(t, level.barrels[0].material == .Plasma)
    testing.expect(t, intro_roof(CAVE_ARCH_START_X) > intro_roof(CAVE_EXIT_X-100))
    testing.expect(t, intro_roof(CAVE_EXIT_X-100) > intro_roof(CAVE_EXIT_X))
    testing.expect(t, intro_roof(CAVE_EXIT_X) == 0)
    low, high := FLOOR_Y, FLOOR_Y
    turns := 0
    last_slope := 0
    for x := 250; x < CAVE_EXIT_X; x += 25 {
        y := level.terrain[x]
        low = min(low, y)
        high = max(high, y)
        if x+25 >= CAVE_EXIT_X { continue }
        slope := 0
        if level.terrain[x+25] > y { slope = 1 }
        if level.terrain[x+25] < y { slope = -1 }
        if slope != 0 {
            if last_slope != 0 && last_slope != slope { turns += 1 }
            last_slope = slope
        }
    }
    testing.expect(t, low <= FLOOR_Y-8 && high >= FLOOR_Y+8)
    testing.expect(t, turns >= 5)
    for i := 0; i < w.enemy_count; i += 1 {
        testing.expect(t, w.enemies[i].x > CAVE_EXIT_X)
    }
}

@test
intro_delays_first_dialogue_then_spawns_one_guard :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    level := new(Level)
    defer free(level)
    w.random_state = 1
    generate_level(w, level, 17)
    player := Player{x = INTRO_EGG_X+1, y = FLOOR_Y-PLAYER_H, health = 100}
    intro := Intro{phase = .Hatching}
    for _ in 0..<55 { intro_update(&intro, w, level, &player, false) }
    testing.expect(t, intro.phase == .Movement)
    intro_update(&intro, w, level, &player, false)
    testing.expect(t, intro.phase == .Movement)
    player.x = INTRO_EGG_X+INTRO_AWAKENING_DISTANCE-1
    intro_update(&intro, w, level, &player, false)
    testing.expect(t, intro.phase == .Movement)
    player.x += 1
    intro_update(&intro, w, level, &player, false)
    testing.expect(t, intro.phase == .FirstDialogue)
    intro.awakening_spoken = true
    intro.phase = .Movement // The dialogue is advanced by the UI input loop.
    testing.expect(t, !intro.inventory_visible)
    player.x = INTRO_GATE_X-50
    intro_update(&intro, w, level, &player, false)
    testing.expect(t, intro.phase == .FireHint)
    intro_update(&intro, w, level, &player, true)
    testing.expect(t, intro.phase == .Gate && intro.inventory_visible)
    before := w.enemy_count
    player.x = INTRO_GATE_X+INTRO_GATE_WIDTH+3
    intro_update(&intro, w, level, &player, false)
    testing.expect(t, intro.phase == .Guards)
    testing.expect(t, w.enemy_count == before+1)
    testing.expect(t, !intro_guard_visible(&intro, w, 400, 80))
    testing.expect(t, intro_guard_visible(&intro, w, 440, 80))
}
