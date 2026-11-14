package main

import rl "vendor:raylib"
import "core:c"

CAVE_EXIT_X :: 1100
CAVE_ARCH_START_X :: CAVE_EXIT_X-220
INTRO_EGG_X :: 153
INTRO_AWAKENING_DISTANCE :: 32
INTRO_GATE_X :: 525
INTRO_GATE_WIDTH :: 8
INTRO_GUARD_X :: 790
INTRO_BARREL_X :: 960

IntroPhase :: enum {Egg, Hatching, FirstDialogue, Movement, FireHint, Gate, Guards, KnightDialogue, DragonShockDialogue, KnightThreatDialogue, DragonVowDialogue, SlowMotion, Fight, Barrel, Complete}
Intro :: struct {
    phase: IntroPhase,
    hatch_time: f32,
    awakening_spoken: bool,
    inventory_visible: bool,
    guard_start: int,
    guard_spawned: bool,
}

intro_roof :: proc(x: int) -> int {
    // Broad cave silhouette with small deterministic rock teeth.
    broad := (x/31)%5
    rough := (x*17+x*x/19)%7
    height := 166+broad*2+rough
    if x >= CAVE_ARCH_START_X {
        distance := max(0, CAVE_EXIT_X-x)
        t := f32(distance)/f32(CAVE_EXIT_X-CAVE_ARCH_START_X)
        eased := t*t*(3-2*t)
        height = int(f32(height)*eased+0.5)
    }
    return height
}

intro_floor :: proc(x: int) -> int {
    if x < 215 { return FLOOR_Y }
    section := x/46
    offset := x%46
    seed_a := u32(section)*747796405+2891336453
    seed_b := u32(section+1)*747796405+2891336453
    a := int((seed_a ~ (seed_a>>16))%25)-12
    b := int((seed_b ~ (seed_b>>16))%25)-12
    t := f32(offset)/46
    eased := t*t*(3-2*t)
    height := FLOOR_Y+int(f32(a)+f32(b-a)*eased+0.5)
    if x < 251 {
        blend := f32(x-215)/36
        return FLOOR_Y+int(f32(height-FLOOR_Y)*blend+0.5)
    }
    return height
}

prepare_intro_terrain :: proc(level: ^Level) {
    join_y := level.terrain[CAVE_EXIT_X+64]
    for x := 0; x <= CAVE_EXIT_X; x += 1 {
        level.terrain[x] = intro_floor(x)
    }
    flatten_terrain(level, INTRO_GATE_X-13, INTRO_GATE_X+INTRO_GATE_WIDTH+13)
    flatten_terrain(level, INTRO_GUARD_X-12, INTRO_GUARD_X+36)
    flatten_terrain(level, INTRO_BARREL_X-8, INTRO_BARREL_X+BARREL_W+8)
    from_y := level.terrain[CAVE_EXIT_X]
    for x := CAVE_EXIT_X+1; x < CAVE_EXIT_X+64; x += 1 {
        t := f32(x-CAVE_EXIT_X)/64
        eased := t*t*(3-2*t)
        level.terrain[x] = int(f32(from_y)+f32(join_y-from_y)*eased+0.5)
    }
}

place_intro_cave :: proc(w: ^World, level: ^Level) {
    for x := 0; x <= CAVE_EXIT_X; x += 1 {
        top := intro_roof(x)
        for y := 0; y <= top; y += 1 { place(w, x, y, .Stone) }
        if x < 18 {
            edge := 12+(x*7%6)
            for y := top; y < level.terrain[x]; y += 1 {
                if x < edge { place(w, x, y, .Stone) }
            }
        }
    }
    // The gate meets both floor and ceiling, so it must be burned through.
    for x := INTRO_GATE_X; x < INTRO_GATE_X+INTRO_GATE_WIDTH; x += 1 {
        for y := intro_roof(x)+1; y < level.terrain[x]; y += 1 { place(w, x, y, .Wood) }
    }
}

intro_update :: proc(intro: ^Intro, w: ^World, level: ^Level, p: ^Player,
                     click: bool) {
    switch intro.phase {
    case .Hatching:
        intro.hatch_time += PHYSICS_DT
        if intro.hatch_time >= 0.9 { intro.phase = .Movement }
    case .Movement:
        if !intro.awakening_spoken && p.x >= INTRO_EGG_X+INTRO_AWAKENING_DISTANCE {
            intro.phase = .FirstDialogue
        } else if intro.awakening_spoken && p.x >= INTRO_GATE_X-63 {
            intro.phase = .FireHint
        }
    case .FireHint:
        if click {
            intro.inventory_visible = true
            intro.phase = .Gate
        }
    case .Gate:
        if p.x > INTRO_GATE_X+INTRO_GATE_WIDTH+2 {
            intro.guard_start = w.enemy_count
            intro.guard_spawned = spawn_enemy_near(w, level, INTRO_GUARD_X, .Knight, 0, 0, 0)
            intro.phase = .Guards
        }
    case .Guards:
        // The camera checks visibility after following the player.
    case .SlowMotion:
        if click { intro.phase = .Fight }
    case .Fight:
        if p.x >= INTRO_BARREL_X-43 { intro.phase = .Barrel }
    case .Barrel:
    case .Egg, .FirstDialogue, .KnightDialogue, .DragonShockDialogue, .KnightThreatDialogue, .DragonVowDialogue, .Complete:
    }
}

intro_guard_visible :: proc(intro: ^Intro, w: ^World, camera_x, camera_y: f32) -> bool {
    if intro.phase != .Guards || !intro.guard_spawned || intro.guard_start >= w.enemy_count { return false }
    enemy := &w.enemies[intro.guard_start]
    return enemy.alive &&
           f32(enemy.x+enemy_width(enemy.kind)) > camera_x && f32(enemy.x) < camera_x+VIEW_W &&
           f32(enemy.y+enemy_height(enemy.kind)) > camera_y && f32(enemy.y) < camera_y+VIEW_H
}

intro_prompt_index :: proc(phase: IntroPhase) -> int {
    switch phase {
    case .Egg: return 0
    case .Movement: return 1
    case .FireHint, .Gate: return 2
    case .SlowMotion: return 3
    case .Barrel: return 4
    case .Hatching, .FirstDialogue, .Guards, .KnightDialogue, .DragonShockDialogue, .KnightThreatDialogue, .DragonVowDialogue, .Fight, .Complete: return -1
    }
    return -1
}

draw_intro_prompt :: proc(texture: rl.Texture2D) {
    if !rl.IsTextureValid(texture) { return }
    width := c.int(texture.width)
    height := c.int(texture.height)
    x := c.int((CANVAS_W-int(width))/2)
    y := c.int(CANVAS_H-int(height)-24)
    rl.DrawRectangle(x-12, y-8, width+24, height+16, rl.Color{9, 15, 24, 206})
    rl.DrawTexture(texture, x, y, rl.WHITE)
}

draw_intro_egg :: proc(egg: rl.Texture2D, intro: ^Intro, camera_px_x, camera_px_y: int) {
    if !rl.IsTextureValid(egg) || (intro.phase != .Egg && intro.phase != .Hatching) { return }
    x := f32(INTRO_EGG_X*CELL_SIZE-camera_px_x)
    y := f32((FLOOR_Y-18)*CELL_SIZE-camera_px_y)
    if intro.phase == .Hatching && intro.hatch_time > 0.55 {
        // Two shell halves tumble apart to reveal the already loaded dragon.
        amount := min(f32(1), (intro.hatch_time-0.55)/0.35)
        left := rl.Rectangle{0, 0, 8, 18}
        right := rl.Rectangle{8, 0, 8, 18}
        rl.DrawTexturePro(egg, left, rl.Rectangle{x-20*amount, y+10*amount, 24, 54}, rl.Vector2{}, -18*amount, rl.WHITE)
        rl.DrawTexturePro(egg, right, rl.Rectangle{x+24+20*amount, y+10*amount, 24, 54}, rl.Vector2{}, 18*amount, rl.WHITE)
        return
    }
    rl.DrawTexturePro(egg, rl.Rectangle{0, 0, 16, 18}, rl.Rectangle{x, y, 48, 54}, rl.Vector2{}, 0, rl.WHITE)
    if intro.phase == .Hatching {
        crack := rl.Color{83, 36, 61, 255}
        sx, sy := c.int(x), c.int(y)
        if intro.hatch_time > 0.2 {
            rl.DrawLine(sx+25, sy+15, sx+20, sy+22, crack)
            rl.DrawLine(sx+20, sy+22, sx+27, sy+29, crack)
        }
        if intro.hatch_time > 0.4 {
            rl.DrawLine(sx+27, sy+29, sx+17, sy+36, crack)
            rl.DrawLine(sx+17, sy+36, sx+29, sy+43, crack)
        }
    }
}

draw_cave_backdrop :: proc(tile: rl.Texture2D, camera_x, camera_y: f32) {
    if !rl.IsTextureValid(tile) { return }
    tile_size := int(tile.width)
    if tile_size <= 0 { return }
    cave_right := min(f32(CANVAS_W), (f32(CAVE_EXIT_X)-camera_x)*CELL_SIZE)
    if cave_right <= 0 { return }
    arch_left := (f32(CAVE_ARCH_START_X)-camera_x)*CELL_SIZE
    dark := rl.Color{25, 27, 39, 255}
    if arch_left > 0 { rl.DrawRectangle(0, 0, c.int(min(f32(CANVAS_W), arch_left)), CANVAS_H, dark) }
    rl.DrawRectangleGradientH(c.int(arch_left), 0,
        (CAVE_EXIT_X-CAVE_ARCH_START_X)*CELL_SIZE, CANVAS_H,
        dark, rl.Color{25, 27, 39, 0})
    rl.BeginScissorMode(0, 0, c.int(cave_right), CANVAS_H)
    first := int(camera_x/f32(tile_size))*tile_size
    first_y := int(camera_y/f32(tile_size))*tile_size
    for world_x := first; world_x < min(CAVE_EXIT_X, int(camera_x)+VIEW_W+tile_size); world_x += tile_size {
        if world_x < 0 { continue }
        screen_x := f32(world_x)*CELL_SIZE-camera_x*CELL_SIZE
        for world_y := first_y; world_y < int(camera_y)+VIEW_H+tile_size; world_y += tile_size {
            screen_y := f32(world_y)*CELL_SIZE-camera_y*CELL_SIZE
            alpha := 255
            if world_x >= CAVE_ARCH_START_X {
                alpha = max(0, min(255, (CAVE_EXIT_X-world_x)*255/(CAVE_EXIT_X-CAVE_ARCH_START_X)))
            }
            rl.DrawTexturePro(tile, rl.Rectangle{0, 0, f32(tile_size), f32(tile_size)},
                rl.Rectangle{screen_x, screen_y, f32(tile_size*CELL_SIZE), f32(tile_size*CELL_SIZE)}, rl.Vector2{}, 0,
                rl.Color{108, 115, 139, u8(alpha)})
        }
    }
    rl.EndScissorMode()
}
