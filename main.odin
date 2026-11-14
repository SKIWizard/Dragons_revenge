package main

import rl "vendor:raylib"
import "core:c"

when ODIN_OS == .JS {
    foreign import emscripten "env.o"
    foreign emscripten {
        emscripten_sleep :: proc "c" (milliseconds: c.int) ---
    }
}

PHYSICS_DT :: f32(1.0/60.0)
PLAYER_W :: 14
PLAYER_H :: 20
GROUND_PROBE_DISTANCE :: 4
MAX_STEP_HEIGHT :: 4
FLOOR_Y :: 242

COYOTE_TIME :: f32(0.10)
JUMP_BUFFER_TIME :: f32(0.20)
JUMP_HOLD_TIME :: f32(0.20)
CEILING_GRACE_TIME :: f32(0.05)
WALL_RETENTION_TIME :: f32(0.06)
MAX_RUN_SPEED :: f32(117)
RUN_ACCELERATION :: f32(1300)
RUN_DECELERATION :: f32(1500)
RUN_REVERSE_ACCELERATION :: f32(1300)
AIR_CONTROL :: f32(0.70)
ABOVE_CAP_DECELERATION :: f32(600)
JUMP_SPEED :: f32(-220)
JUMP_HORIZONTAL_BOOST :: f32(35)
GRAVITY :: f32(1000)
APEX_GRAVITY_MULTIPLIER :: f32(0.5)
APEX_SPEED_THRESHOLD :: f32(60)
TERMINAL_VELOCITY :: f32(360)
CORNER_CORRECTION :: 6
DINO_FRAME_SIZE :: 24
DINO_IDLE_FRAMES :: 4
DINO_WALK_FRAMES :: 7

Animation :: enum {Idle, Walk, Air}

animation_frame :: proc(mode: Animation, elapsed: f32) -> int {
    switch mode {
    case .Idle: return int(elapsed / 0.15) % DINO_IDLE_FRAMES
    case .Walk: return 4 + int(elapsed / 0.09) % DINO_WALK_FRAMES
    case .Air: return 0
    }
    return 0
}

Input :: struct {
    direction: int,
    jump_held, jump_pressed: bool,
}

Player :: struct {
    x, y: int,
    health: int,
    facing: int,
    vx, vy: f32,
    remainder_x, remainder_y: f32,
    grounded: bool,
    coyote, jump_buffer, jump_hold, ceiling_grace: f32,
    wall_retention, retained_vx: f32,
    ceiling_hit: bool,
    potion_heal_progress: f32,
    hurt_time: f32,
    empowered: bool,
}

damage_player :: proc(w: ^World, p: ^Player, amount: int) {
    if amount <= 0 || p.health <= 0 { return }
    p.health = max(0, p.health-amount)
    p.hurt_time = 1.0
    for n := 0; n < 8; n += 1 {
        side := -1
        x := p.x-1
        if n%2 == 1 { side = 1; x = p.x+PLAYER_W }
        y := p.y+5+int(rand(w)%10)
        if !inside(x, y) || kind_at(w, x, y) != .Empty || actor_occupies(w, x, y) { continue }
        place(w, x, y, .Blood)
        drop := &w.cells[index(x, y)]
        drop.vx = f32(side)*(0.5+f32(rand(w)%130)/100)
        drop.vy = -0.5-f32(rand(w)%100)/100
        drop.scatter_ticks = u8(7+rand(w)%7)
    }
}

heal_from_potion :: proc(w: ^World, p: ^Player) {
    if p.health >= PLAYER_MAX_HEALTH { p.potion_heal_progress = 0; return }
    touching := false
    for y := p.y+PLAYER_H-7; y <= p.y+PLAYER_H+1 && !touching; y += 1 {
        for x := p.x-1; x <= p.x+PLAYER_W; x += 1 {
            if inside(x, y) && kind_at(w, x, y) == .Potion { touching = true; break }
        }
    }
    if !touching { p.potion_heal_progress = 0; return }
    p.potion_heal_progress += PHYSICS_DT
    if p.potion_heal_progress >= 0.18 {
        p.potion_heal_progress -= 0.18
        p.health = min(PLAYER_MAX_HEALTH, p.health+1)
    }
}

player_hits :: proc(w: ^World, x, y: int) -> bool {
    for cy := y; cy < y+PLAYER_H; cy += 1 {
        for cx := x; cx < x+PLAYER_W; cx += 1 {
            if cx < 0 || cx >= WORLD_W || cy < 0 { return true }
            if cy >= WORLD_H { continue }
            kind := w.cells[index(cx, cy)].kind
            if solid(kind) || powder(kind) { return true }
        }
    }
    return false
}

// Step-up clearance must ignore movable cells. The destination check below
// displaces powders and liquids through the normal actor collision path.
player_hits_static :: proc(w: ^World, x, y: int) -> bool {
    for cy := y; cy < y+PLAYER_H; cy += 1 {
        for cx := x; cx < x+PLAYER_W; cx += 1 {
            if cx < 0 || cx >= WORLD_W || cy < 0 { return true }
            if cy < WORLD_H && solid(kind_at(w, cx, cy)) { return true }
        }
    }
    return false
}

// Jump permission looks only below the feet, including a small gap that can
// appear when water and powder move beneath the character.
player_near_support :: proc(w: ^World, x, y: int) -> bool {
    for gap := 0; gap <= GROUND_PROBE_DISTANCE; gap += 1 {
        foot_y := y+PLAYER_H+gap
        if foot_y < 0 || foot_y >= WORLD_H { continue }
        for foot_x := x; foot_x < x+PLAYER_W; foot_x += 1 {
            if !inside(foot_x, foot_y) { continue }
            kind := kind_at(w, foot_x, foot_y)
            if solid(kind) || powder(kind) { return true }
        }
    }
    return false
}

approach :: proc(current, target, amount: f32) -> f32 {
    if current < target {
        value := current+amount
        if value > target { return target }
        return value
    }
    value := current-amount
    if value < target { return target }
    return value
}

start_jump :: proc(p: ^Player, direction: int) {
    p.vy = JUMP_SPEED
    p.remainder_y = 0
    p.jump_hold = JUMP_HOLD_TIME
    p.ceiling_grace = CEILING_GRACE_TIME
    p.ceiling_hit = false
    p.coyote = 0
    p.jump_buffer = 0
    p.grounded = false
    if direction != 0 { p.vx += f32(direction)*JUMP_HORIZONTAL_BOOST }
}

// Each candidate's path must be free at the current height.
correct_jump_corner :: proc(p: ^Player, w: ^World) -> bool {
    sides := [2]int{-1, 1}
    for distance := 1; distance <= CORNER_CORRECTION; distance += 1 {
        for side in sides {
            path_clear := true
            for step := 1; step <= distance; step += 1 {
                if player_hits(w, p.x+step*side, p.y) { path_clear = false; break }
            }
            if path_clear && player_can_enter(w, p.x+distance*side, p.y-1, -1) {
                p.x += distance*side
                p.y -= 1
                p.ceiling_hit = false
                return true
            }
        }
    }
    return false
}

try_step_up :: proc(p: ^Player, w: ^World, direction: int) -> bool {
    if p.vy < 0 || !player_near_support(w, p.x, p.y) { return false }
    for rise := 1; rise <= MAX_STEP_HEIGHT; rise += 1 {
        if player_hits_static(w, p.x, p.y-rise) { break }
        if player_can_enter(w, p.x+direction, p.y-rise, 0) {
            p.x += direction
            p.y -= rise
            p.vy = 0
            p.remainder_y = 0
            return true
        }
    }
    return false
}

update_player :: proc(p: ^Player, w: ^World, input: Input) {
    if input.direction != 0 { p.facing = input.direction }
    grounded_at_start := player_hits(w, p.x, p.y+1)
    p.grounded = grounded_at_start
    if grounded_at_start || (p.vy >= 0 && player_near_support(w, p.x, p.y)) { p.coyote = COYOTE_TIME }
    if input.jump_pressed { p.jump_buffer = JUMP_BUFFER_TIME }
    if p.jump_buffer > 0 && p.coyote > 0 { start_jump(p, input.direction) }

    target_x := f32(input.direction)*MAX_RUN_SPEED
    acceleration := RUN_ACCELERATION
    if input.direction == 0 {
        acceleration = RUN_DECELERATION
    } else if p.vx*f32(input.direction) < 0 {
        acceleration = RUN_REVERSE_ACCELERATION
    } else if p.vx*f32(input.direction) > MAX_RUN_SPEED {
        acceleration = ABOVE_CAP_DECELERATION
    }
    if !p.grounded { acceleration *= AIR_CONTROL }
    p.vx = approach(p.vx, target_x, acceleration*PHYSICS_DT)

    if p.grounded {
        p.vy = 0
        p.remainder_y = 0
    } else {
        if !input.jump_held { p.jump_hold = 0 }
        if p.ceiling_hit && p.ceiling_grace > 0 && !player_hits(w, p.x, p.y-1) { p.ceiling_hit = false }
        if p.ceiling_hit && p.ceiling_grace > 0 {
            p.vy = 0
        } else if input.jump_held && p.jump_hold > 0 && p.vy <= 0 {
            p.vy = JUMP_SPEED
        } else {
            gravity := GRAVITY
            if input.jump_held && p.vy > -APEX_SPEED_THRESHOLD && p.vy < APEX_SPEED_THRESHOLD {
                gravity *= APEX_GRAVITY_MULTIPLIER
            }
            p.vy += gravity*PHYSICS_DT
        }
        if p.vy > TERMINAL_VELOCITY { p.vy = TERMINAL_VELOCITY }
    }

    // Continuous velocities become single-cell collision steps.
    p.remainder_x += p.vx*PHYSICS_DT
    move_x := int(p.remainder_x)
    p.remainder_x -= f32(move_x)
    step_x := 1
    if move_x < 0 { step_x = -1; move_x = -move_x }
    for _ in 0..<move_x {
        if !player_can_enter(w, p.x+step_x, p.y, 0) {
            if try_step_up(p, w, step_x) { continue }
            if p.wall_retention <= 0 { p.retained_vx = p.vx; p.wall_retention = WALL_RETENTION_TIME }
            p.vx = 0
            p.remainder_x = 0
            break
        }
        p.x += step_x
    }

    p.remainder_y += p.vy*PHYSICS_DT
    move_y := int(p.remainder_y)
    p.remainder_y -= f32(move_y)
    step_y := 1
    if move_y < 0 { step_y = -1; move_y = -move_y }
    for _ in 0..<move_y {
        if !player_can_enter(w, p.x, p.y+step_y, step_y) {
            if step_y < 0 && correct_jump_corner(p, w) { continue }
            if step_y < 0 {
                if p.ceiling_grace > 0 { p.ceiling_hit = true } else { p.jump_hold = 0 }
            }
            p.vy = 0
            p.remainder_y = 0
            break
        }
        p.y += step_y
    }

    if p.wall_retention > 0 && p.retained_vx != 0 {
        side := 1
        if p.retained_vx < 0 { side = -1 }
        if !player_hits(w, p.x+side, p.y) {
            p.vx = p.retained_vx
            p.retained_vx = 0
            p.wall_retention = 0
        }
    }
    p.grounded = player_hits(w, p.x, p.y+1)
    if p.grounded && !grounded_at_start && p.jump_buffer > 0 { start_jump(p, input.direction) }
    if p.grounded || (p.vy >= 0 && player_near_support(w, p.x, p.y)) {
        p.coyote = COYOTE_TIME
    } else if p.coyote > 0 { p.coyote -= PHYSICS_DT }
    if p.jump_buffer > 0 { p.jump_buffer -= PHYSICS_DT }
    if p.jump_hold > 0 { p.jump_hold -= PHYSICS_DT }
    if p.ceiling_grace > 0 {
        p.ceiling_grace -= PHYSICS_DT
        if p.ceiling_grace <= 0 && p.ceiling_hit { p.jump_hold = 0; p.ceiling_hit = false }
    }
    if p.wall_retention > 0 {
        p.wall_retention -= PHYSICS_DT
        if p.wall_retention <= 0 { p.retained_vx = 0 }
    }
    set_player_collision(w, p)
}

main :: proc() {
    w := new(World)
    defer free(w)
    level := new(Level)
    defer free(level)
    p := Player{x = INTRO_EGG_X+1, y = FLOOR_Y-PLAYER_H, facing = 1, health = PLAYER_MAX_HEALTH}
    previous_x, previous_y := p.x, p.y
    camera := CameraState{y = 80}
    sandbox_menu := SandboxMenu{selected = .Fire}
    inventory := starting_inventory()
    intro := Intro{phase = .Egg}
    dialogue := DialogueState{}
    spit_state := SpitState{}
    movement_fx := MovementFX{random_state = 0xD0571234}
    game_over := false
    screen := GameScreen.Title
    boss_encounter := BossEncounter.Waiting
    master_volume := GAME_MASTER_VOLUME

    rl.SetConfigFlags({.WINDOW_RESIZABLE})
    rl.InitWindow(CANVAS_W, CANVAS_H, "Dragons Revenge")
    defer rl.CloseWindow()
    rl.SetExitKey(.KEY_NULL)
    game_audio := init_game_audio()
    defer unload_game_audio(&game_audio)
    canvas := rl.LoadRenderTexture(CANVAS_W, CANVAS_H)
    if !rl.IsRenderTextureValid(canvas) { return }
    defer rl.UnloadRenderTexture(canvas)
    rl.SetTextureFilter(canvas.texture, .POINT)
    slowmo_shader_path: cstring = "assets/shaders/intro_slowmo.fs"
    when ODIN_OS == .JS { slowmo_shader_path = "assets/shaders/intro_slowmo_web.fs" }
    slowmo_shader := rl.LoadShader(nil, slowmo_shader_path)
    defer rl.UnloadShader(slowmo_shader)
    stone_texture := load_material_texture("assets/textures/stone_texture.png")
    defer unload_material_texture(&stone_texture)
    wood_texture := load_material_texture("assets/textures/wood_texture.png")
    defer unload_material_texture(&wood_texture)
    rl.HideCursor()
    defer rl.ShowCursor()
    dragon_sprite := rl.LoadTexture("DinoSprites - vita.png")
    if rl.IsTextureValid(dragon_sprite) { rl.SetTextureFilter(dragon_sprite, .POINT) }
    defer rl.UnloadTexture(dragon_sprite)
    mort_sprite := rl.LoadTexture("dinoCharactersVersion1.1/sheets/DinoSprites - mort.png")
    if rl.IsTextureValid(mort_sprite) { rl.SetTextureFilter(mort_sprite, .POINT) }
    defer rl.UnloadTexture(mort_sprite)
    jump_sprite := rl.LoadTexture("assets/sprites/dino_vita_jump.png")
    if rl.IsTextureValid(jump_sprite) { rl.SetTextureFilter(jump_sprite, .POINT) }
    defer rl.UnloadTexture(jump_sprite)
    mort_jump_sprite := rl.LoadTexture("assets/sprites/dino_mort_jump.png")
    if rl.IsTextureValid(mort_jump_sprite) { rl.SetTextureFilter(mort_jump_sprite, .POINT) }
    defer rl.UnloadTexture(mort_jump_sprite)
    spit_sprite := rl.LoadTexture("assets/sprites/dino_vita_spit.png")
    if rl.IsTextureValid(spit_sprite) { rl.SetTextureFilter(spit_sprite, .POINT) }
    defer rl.UnloadTexture(spit_sprite)
    mort_spit_sprite := rl.LoadTexture("assets/sprites/dino_mort_spit.png")
    if rl.IsTextureValid(mort_spit_sprite) { rl.SetTextureFilter(mort_spit_sprite, .POINT) }
    defer rl.UnloadTexture(mort_spit_sprite)
    spit_run_sprite := rl.LoadTexture("assets/sprites/dino_vita_spit_run.png")
    if rl.IsTextureValid(spit_run_sprite) { rl.SetTextureFilter(spit_run_sprite, .POINT) }
    defer rl.UnloadTexture(spit_run_sprite)
    mort_spit_run_sprite := rl.LoadTexture("assets/sprites/dino_mort_spit_run.png")
    if rl.IsTextureValid(mort_spit_run_sprite) { rl.SetTextureFilter(mort_spit_run_sprite, .POINT) }
    defer rl.UnloadTexture(mort_spit_run_sprite)
    background := rl.LoadTexture("assets/backgrounds/medieval_panorama.png")
    if rl.IsTextureValid(background) { rl.SetTextureFilter(background, .BILINEAR) }
    defer rl.UnloadTexture(background)
    cave_tiles := rl.LoadTexture("assets/backgrounds/cave_brick_seamless.png")
    if rl.IsTextureValid(cave_tiles) { rl.SetTextureFilter(cave_tiles, .POINT) }
    defer rl.UnloadTexture(cave_tiles)
    menu_labels := [4]rl.Texture2D{
        rl.LoadTexture("assets/ui/menu_play.png"),
        rl.LoadTexture("assets/ui/menu_settings.png"),
        rl.LoadTexture("assets/ui/menu_volume.png"),
        rl.LoadTexture("assets/ui/menu_back.png"),
    }
    defer for label in menu_labels { rl.UnloadTexture(label) }
    egg_sprite := rl.LoadTexture("assets/sprites/intro_egg.png")
    if rl.IsTextureValid(egg_sprite) { rl.SetTextureFilter(egg_sprite, .POINT) }
    defer rl.UnloadTexture(egg_sprite)
    dragon_portrait := rl.LoadTexture("dragon_icon.png")
    defer rl.UnloadTexture(dragon_portrait)
    knight_portrait := rl.LoadTexture("blue_knight_icon.png")
    defer rl.UnloadTexture(knight_portrait)
    boss_portrait := rl.LoadTexture("boss_knight_icon.png")
    defer rl.UnloadTexture(boss_portrait)
    dialogue_text := [5]rl.Texture2D{
        rl.LoadTexture("assets/ui/dialogue_awakening.png"),
        rl.LoadTexture("assets/ui/dialogue_knight.png"),
        rl.LoadTexture("assets/ui/dialogue_dragon_shock.png"),
        rl.LoadTexture("assets/ui/dialogue_knight_threat.png"),
        rl.LoadTexture("assets/ui/dialogue_dragon_vow.png"),
    }
    defer for sheet in dialogue_text { rl.UnloadTexture(sheet) }
    boss_dialogue_text := [4]rl.Texture2D{
        rl.LoadTexture("assets/ui/dialogue_boss_question.png"),
        rl.LoadTexture("assets/ui/dialogue_boss_answer.png"),
        rl.LoadTexture("assets/ui/dialogue_boss_defiance.png"),
        rl.LoadTexture("assets/ui/dialogue_boss_farewell.png"),
    }
    defer for sheet in boss_dialogue_text { rl.UnloadTexture(sheet) }
    intro_cards := [5]rl.Texture2D{
        rl.LoadTexture("assets/ui/intro_egg.png"),
        rl.LoadTexture("assets/ui/intro_move.png"),
        rl.LoadTexture("assets/ui/intro_fire.png"),
        rl.LoadTexture("assets/ui/intro_fight.png"),
        rl.LoadTexture("assets/ui/intro_barrel.png"),
    }
    defer for card in intro_cards { rl.UnloadTexture(card) }
    barrel_texture := rl.LoadTexture("assets/sprites/barrel_break.png")
    if rl.IsTextureValid(barrel_texture) { rl.SetTextureFilter(barrel_texture, .POINT) }
    defer rl.UnloadTexture(barrel_texture)
    eat_sprite := rl.LoadTexture("assets/sprites/dino_vita_eat.png")
    if rl.IsTextureValid(eat_sprite) { rl.SetTextureFilter(eat_sprite, .POINT) }
    defer rl.UnloadTexture(eat_sprite)
    mort_eat_sprite := rl.LoadTexture("assets/sprites/dino_mort_eat.png")
    if rl.IsTextureValid(mort_eat_sprite) { rl.SetTextureFilter(mort_eat_sprite, .POINT) }
    defer rl.UnloadTexture(mort_eat_sprite)
    material_icons := rl.LoadTexture("assets/sprites/material_icons.png")
    if rl.IsTextureValid(material_icons) { rl.SetTextureFilter(material_icons, .POINT) }
    defer rl.UnloadTexture(material_icons)
    knight_sprite := rl.LoadTexture("assets/sprites/knight_blue.png")
    if rl.IsTextureValid(knight_sprite) { rl.SetTextureFilter(knight_sprite, .POINT) }
    defer rl.UnloadTexture(knight_sprite)
    ogre_sprite := rl.LoadTexture("assets/sprites/ogre.png")
    if rl.IsTextureValid(ogre_sprite) { rl.SetTextureFilter(ogre_sprite, .POINT) }
    defer rl.UnloadTexture(ogre_sprite)
    barbarian_sprite := rl.LoadTexture("assets/sprites/barbarian.png")
    if rl.IsTextureValid(barbarian_sprite) { rl.SetTextureFilter(barbarian_sprite, .POINT) }
    defer rl.UnloadTexture(barbarian_sprite)
    boss_sprite := rl.LoadTexture("assets/sprites/free_knight_boss.png")
    if rl.IsTextureValid(boss_sprite) { rl.SetTextureFilter(boss_sprite, .POINT) }
    defer rl.UnloadTexture(boss_sprite)
    ending_art := rl.LoadTexture("assets/backgrounds/ending_sunset_wide.png")
    defer rl.UnloadTexture(ending_art)
    ending_title := rl.LoadTexture("assets/ui/ending_title.png")
    defer rl.UnloadTexture(ending_title)
    when ODIN_OS != .JS { rl.SetTargetFPS(60) }
    accumulator: f32 = 0
    pending_jump := false
    pending_spit_click := false
    animation := Animation.Idle
    animation_elapsed: f32 = 0
    for !rl.WindowShouldClose() {
        if rl.IsKeyPressed(.F11) { rl.ToggleFullscreen() }
        viewport := canvas_viewport(int(rl.GetScreenWidth()), int(rl.GetScreenHeight()))
        dt := rl.GetFrameTime()
        if dt > 0.05 { dt = 0.05 }
        tick_game_audio(&game_audio, dt)
        menu_mouse, menu_inside := canvas_mouse(rl.GetMousePosition(), viewport)
        menu_x, menu_y := int(menu_mouse.x), int(menu_mouse.y)
        returned_from_game_over := false
        started_this_frame := false
        if screen == .GameOver && (rl.GetKeyPressed() != .KEY_NULL ||
                                   rl.IsMouseButtonPressed(.LEFT) || rl.IsMouseButtonPressed(.RIGHT)) {
            screen = .Title
            returned_from_game_over = true
            play_game_sound(&game_audio, .UiBack, 0.32)
        }
        if screen == .Ending {
            if rl.GetKeyPressed() != .KEY_NULL || rl.IsMouseButtonPressed(.LEFT) || rl.IsMouseButtonPressed(.RIGHT) {
                screen = .Title
                returned_from_game_over = true
                play_game_sound(&game_audio, .UiBack, 0.32)
            } else {
                rl.BeginTextureMode(canvas)
                draw_ending_screen(ending_art, ending_title)
                rl.EndTextureMode()
                rl.BeginDrawing()
                rl.ClearBackground(rl.BLACK)
                draw_canvas(canvas, viewport)
                rl.EndDrawing()
                when ODIN_OS == .JS { emscripten_sleep(16) }
                continue
            }
        }
        if screen == .Title || screen == .Settings {
            old_volume := master_volume
            start_game := false
            if !returned_from_game_over {
                start_game = update_game_menu(&screen, &master_volume, menu_x, menu_y,
                menu_inside && rl.IsMouseButtonPressed(.LEFT),
                menu_inside && rl.IsMouseButtonDown(.LEFT),
                rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.SPACE), rl.IsKeyPressed(.S),
                rl.IsKeyPressed(.ESCAPE), rl.IsKeyPressed(.LEFT), rl.IsKeyPressed(.RIGHT))
            }
            if master_volume != old_volume && game_audio.ready { rl.SetMasterVolume(master_volume) }
            if start_game {
                started_this_frame = true
                play_game_sound(&game_audio, .UiSelect, 0.34)
                w^ = World{}
                w.random_state = u32(rl.GetRandomValue(1, 2_000_000_000))
                level^ = Level{}
                generate_level(w, level, w.random_state)
                w.boss_locked = true
                p = Player{x = INTRO_EGG_X+1, y = level.terrain[INTRO_EGG_X]-PLAYER_H,
                           facing = 1, health = PLAYER_MAX_HEALTH}
                previous_x, previous_y = p.x, p.y
                camera = CameraState{y = 80}
                sandbox_menu = SandboxMenu{selected = .Fire}
                inventory = starting_inventory()
                intro = Intro{phase = .Egg}
                dialogue = DialogueState{}
                spit_state = SpitState{}
                movement_fx = MovementFX{random_state = 0xD0571234}
                game_over = false
                boss_encounter = .Waiting
                accumulator = 0
                pending_jump = false
                pending_spit_click = false
                animation = .Idle
                animation_elapsed = 0
            } else {
                rl.BeginTextureMode(canvas)
                rl.ClearBackground(palette[.Empty][0])
                draw_game_menu(screen, master_volume, cave_tiles, menu_labels, menu_x, menu_y)
                rl.EndTextureMode()
                rl.BeginDrawing()
                rl.ClearBackground(rl.BLACK)
                draw_canvas(canvas, viewport)
                rl.EndDrawing()
                when ODIN_OS == .JS { emscripten_sleep(16) }
                continue
            }
        }
        dialogue_was_active := dialogue.card != .None
        if dialogue_was_active {
            advance := rl.GetKeyPressed() != .KEY_NULL || rl.IsMouseButtonPressed(.LEFT) || rl.IsMouseButtonPressed(.RIGHT)
            card_before := dialogue.card
            letters_before := int(dialogue.visible)
            finished := update_dialogue(&dialogue, dt, advance)
            if !finished { play_dialogue_sfx(&game_audio, card_before, letters_before, int(dialogue.visible)) }
            if finished {
                play_game_sound(&game_audio, .UiSelect, 0.24)
                #partial switch intro.phase {
                case .FirstDialogue:
                    intro.awakening_spoken = true
                    intro.phase = .Movement
                case .KnightDialogue:
                    intro.phase = .DragonShockDialogue
                    begin_dialogue(&dialogue, .DragonShock)
                case .DragonShockDialogue:
                    intro.phase = .KnightThreatDialogue
                    begin_dialogue(&dialogue, .KnightThreat)
                case .KnightThreatDialogue:
                    intro.phase = .DragonVowDialogue
                    begin_dialogue(&dialogue, .DragonVow)
                case .DragonVowDialogue:
                    intro.phase = .SlowMotion
                    play_game_sound(&game_audio, .Charge, 0.48)
                }
                #partial switch card_before {
                case .BossQuestion:
                    begin_dialogue(&dialogue, .BossAnswer)
                case .BossAnswer:
                    boss_encounter = .Fighting
                    w.boss_locked = false
                case .BossDefiance:
                    boss_encounter = .Empowered
                    p.empowered = true
                    p.health = PLAYER_MAX_HEALTH
                    p.hurt_time = 0
                    play_game_sound(&game_audio, .Charge, 0.65)
                case .BossFarewell:
                    screen = .Ending
                }
            }
        }
        if intro.inventory_visible && !dialogue_was_active {
            selected_before := inventory.selected
            handle_inventory_input(&inventory)
            if inventory.selected != selected_before { play_game_sound(&game_audio, .UiMove, 0.20) }
        }
        if intro.phase == .Egg && !started_this_frame && rl.GetKeyPressed() != .KEY_NULL {
            intro.phase = .Hatching
            intro.hatch_time = 0
            play_game_sound(&game_audio, .Egg, 0.55)
        }
        mouse, mouse_inside := canvas_mouse(rl.GetMousePosition(), viewport)
        mouse_x, mouse_y := int(mouse.x), int(mouse.y)
        over_inventory := mouse_x >= 12 && mouse_x < 12+INVENTORY_SIZE*SLOT_SPACING && mouse_y >= 12 && mouse_y < 12+SLOT_SIZE
        over_health := mouse_x >= VIEW_W*CELL_SIZE-206 && mouse_y >= 12 && mouse_y < 42
        over_menu_button := sandbox_menu.unlocked && mouse_in(mouse_x, mouse_y, 12, 80, 190, 30)
        wants_spit := !dialogue_was_active && mouse_inside && rl.IsMouseButtonDown(.LEFT) && !sandbox_menu.open &&
                      !over_inventory && !over_health && !over_menu_button
        fresh_spit := wants_spit && rl.IsMouseButtonPressed(.LEFT)
        if fresh_spit { pending_spit_click = true }
        aim_x := camera.x+mouse.x/f32(CELL_SIZE)
        aim_y := camera.y+mouse.y/f32(CELL_SIZE)
        if !game_over && !dialogue_was_active && intro.inventory_visible && rl.IsKeyPressed(.E) {
            if begin_eat_nearby_barrel(level, &p, &inventory) { play_game_sound(&game_audio, .Pickup, 0.40) }
        }
        if !game_over && !dialogue_was_active && intro.phase > .Hatching && (rl.IsKeyPressed(.SPACE) || rl.IsKeyPressed(.W) || rl.IsKeyPressed(.UP)) { pending_jump = true }
        direction := 0
        if rl.IsKeyDown(.A) || rl.IsKeyDown(.LEFT) { direction -= 1 }
        if rl.IsKeyDown(.D) || rl.IsKeyDown(.RIGHT) { direction += 1 }
        jump_held := rl.IsKeyDown(.SPACE) || rl.IsKeyDown(.W) || rl.IsKeyDown(.UP)
        if !game_over && dialogue.card == .None && !dialogue_was_active {
            if intro.phase == .SlowMotion { accumulator += dt*0.24 }
            else { accumulator += dt }
        } else { accumulator = 0; pending_jump = false; pending_spit_click = false }
        for accumulator >= PHYSICS_DT && !game_over {
            previous_x, previous_y = p.x, p.y
            old_vx, old_vy := p.vx, p.vy
            health_before := p.health
            blasts_before := w.blast_events
            enemy_health_before: [MAX_ENEMIES]int
            enemy_attacking_before: [MAX_ENEMIES]bool
            for i := 0; i < w.enemy_count; i += 1 {
                enemy_health_before[i] = w.enemies[i].health
                enemy_attacking_before[i] = w.enemies[i].attacking
            }
            was_grounded := player_hits(w, p.x, p.y+1)
            input := Input{direction = direction, jump_held = jump_held, jump_pressed = pending_jump}
            if intro.phase <= .Hatching || any_barrel_consuming(level) {
                pending_jump = false
                p.vx, p.vy = 0, 0
            } else {
                update_player(&p, w, input)
            }
            pending_jump = false
            if p.y >= WORLD_H {
                p.health = 0
                game_over = true
                screen = .GameOver
                accumulator = 0
                break
            }
            intro_update(&intro, w, level, &p, pending_spit_click)
            pending_spit_click = false
            sprayed_material := selected_material(&inventory)
            emitted := spit_tick(w, &p, &inventory, &spit_state, aim_x, aim_y,
                                 wants_spit && intro.inventory_visible && intro.phase != .SlowMotion && !any_barrel_consuming(level))
            play_spray_sfx(&game_audio, sprayed_material, emitted)
            step_world(w)
            heal_from_potion(w, &p)
            if intro.phase != .Guards { update_enemies(w, &p) }
            if p.health < health_before { play_game_sound(&game_audio, .HurtPlayer, 0.65) }
            for i := 0; i < w.enemy_count; i += 1 {
                if w.enemies[i].health < enemy_health_before[i] { play_enemy_hurt_sfx(&game_audio) }
                if w.enemies[i].attacking && !enemy_attacking_before[i] {
                    play_game_sound(&game_audio, .Slash, 0.36)
                }
            }
            if intro.phase == .Barrel && p.x > CAVE_EXIT_X {
                intro.phase = .Complete
                start_room_transition(&camera, f32(CAVE_EXIT_X-20), camera.y)
            }
            p.hurt_time = max(0, p.hurt_time-PHYSICS_DT)
            for i := 0; i < level.barrel_count; i += 1 {
                was_broken := level.barrels[i].broken
                update_barrel(w, &level.barrels[i], &p, &inventory)
                if !was_broken && level.barrels[i].broken {
                    cue := SfxCue.Barrel
                    if level.barrels[i].consumed { cue = .Pickup }
                    play_game_sound(&game_audio, cue, 0.49)
                }
            }
            update_movement_fx(&movement_fx, w, &p, previous_x, previous_y,
                               old_vx, old_vy, was_grounded, direction)
            play_movement_sfx(&game_audio, w, &p, previous_x, old_vy, was_grounded)
            if w.blast_events != blasts_before { play_game_sound(&game_audio, .Explosion, 0.72) }
            accumulator -= PHYSICS_DT
            if (boss_encounter == .Fighting || boss_encounter == .Empowered) && boss_is_defeated(w) {
                boss_encounter = .Won
                begin_dialogue(&dialogue, .BossFarewell)
                accumulator = 0
            } else if p.health <= 0 {
                if boss_transformation_ready(boss_encounter, p.health) {
                    boss_encounter = .Defiance
                    begin_dialogue(&dialogue, .BossDefiance)
                    accumulator = 0
                } else {
                    game_over = true
                    screen = .GameOver
                    accumulator = 0
                }
            }
        }
        interpolation := accumulator / PHYSICS_DT
        render_x := f32(previous_x)+(f32(p.x-previous_x))*interpolation
        render_y := f32(previous_y)+(f32(p.y-previous_y))*interpolation
        next_animation := Animation.Air
        if p.grounded {
            next_animation = .Idle
            if p.vx > 10 || p.vx < -10 { next_animation = .Walk }
        }
        if next_animation != animation { animation = next_animation; animation_elapsed = 0 }
        if intro.phase == .SlowMotion { animation_elapsed += dt*0.24 }
        else { animation_elapsed += dt }
        frame := animation_frame(animation, animation_elapsed)
        update_camera(&camera, render_x+PLAYER_W/2, render_y+PLAYER_H/2, dt, p.grounded)
        if intro.phase == .FirstDialogue && dialogue.card == .None { begin_dialogue(&dialogue, .Awakening) }
        if intro_guard_visible(&intro, w, camera.x, camera.y) {
            intro.phase = .KnightDialogue
            begin_dialogue(&dialogue, .Knight)
        }
        if boss_encounter == .Waiting && intro.phase == .Complete && boss_in_view(w, camera.x) {
            boss_encounter = .Opening
            begin_dialogue(&dialogue, .BossQuestion)
            play_game_sound(&game_audio, .Charge, 0.38)
        }
        camera_px_x := int(camera.x*CELL_SIZE+0.5)
        camera_px_y := int(camera.y*CELL_SIZE+0.5)
        if !game_over && dialogue.card == .None && intro.phase > .Hatching {
            handle_sandbox_mouse(&sandbox_menu, w, &p, camera_px_x, camera_px_y,
                                 mouse_x, mouse_y, mouse_inside)
        }
        first_x := int(camera.x)
        first_y := int(camera.y)
        last_x := first_x+VIEW_W+2
        last_y := first_y+VIEW_H+2
        if last_x > WORLD_W { last_x = WORLD_W }
        if last_y > WORLD_H { last_y = WORLD_H }
        rl.BeginTextureMode(canvas)
        rl.ClearBackground(palette[.Empty][0])
        draw_background(background, camera.x)
        draw_cave_backdrop(cave_tiles, camera.x, camera.y)
        for y := first_y; y < last_y; y += 1 {
            for x := first_x; x < last_x; x += 1 {
                cell := w.cells[index(x, y)]
                if cell.kind != .Empty {
                    color := palette[cell.kind][cell.shade]
                    if cell.kind == .Stone {
                        color = material_texture_color(&stone_texture, x, y, FLOOR_Y, color)
                    }
                    if cell.kind == .Wood {
                        color = material_texture_color(&wood_texture, x, y, 0, color)
                    }
                    if cell.kind == .Smoke && cell.max_life > 0 {
                        color.a = u8(40 + 180*int(cell.life)/int(cell.max_life))
                    }
                    if (cell.kind == .KnightDebris || cell.kind == .OgreDebris ||
                        cell.kind == .Blood || cell.kind == .Potion) && cell.life < 40 {
                        color.a = u8(255*max(0, int(cell.life))/40)
                    }
                    if cell.kind == .Wood && cell.burning {
                        color.r = u8(min(255, int(color.r)+55))
                        color.g = u8(min(255, int(color.g)+18))
                        color.b = u8(max(0, int(color.b)-18))
                    }
                    rl.DrawRectangle(c.int(x*CELL_SIZE-camera_px_x), c.int(y*CELL_SIZE-camera_px_y), CELL_SIZE, CELL_SIZE, color)
                }
            }
        }
        for i := 0; i < w.blast_spark_count; i += 1 {
            spark := w.blast_sparks[i]
            color := palette[.Fire][spark.shade]
            color.a = u8(255*int(spark.life)/int(spark.max_life))
            rl.DrawRectangle(
                c.int(spark.x*f32(CELL_SIZE)-f32(camera_px_x)),
                c.int(spark.y*f32(CELL_SIZE)-f32(camera_px_y)),
                CELL_SIZE, CELL_SIZE, color,
            )
        }
        for i := 0; i < level.barrel_count; i += 1 {
            barrel := &level.barrels[i]
            if barrel.x+BARREL_W < first_x || barrel.x > last_x { continue }
            draw_barrel(barrel, barrel_texture, material_icons, camera_px_x, camera_px_y)
        }
        draw_enemies(w, knight_sprite, ogre_sprite, barbarian_sprite, boss_sprite, camera_px_x, camera_px_y)
        draw_movement_fx(&movement_fx, camera_px_x, camera_px_y)
        draw_flying_particles(&spit_state, camera_px_x, camera_px_y)
        eating_barrel := consuming_barrel(level)
        dragon_tint := rl.WHITE
        if p.hurt_time > 0 { dragon_tint = rl.Color{255, 84, 84, 255} }
        if intro.phase == .Egg || intro.phase == .Hatching {
            if intro.phase == .Hatching && intro.hatch_time > 0.55 && rl.IsTextureValid(dragon_sprite) {
                rl.DrawTexturePro(dragon_sprite, rl.Rectangle{0, 0, DINO_FRAME_SIZE, DINO_FRAME_SIZE},
                    rl.Rectangle{f32(int(render_x*CELL_SIZE)-camera_px_x-13),
                                 f32(int(render_y*CELL_SIZE)-camera_px_y-3), 72, 72},
                    rl.Vector2{}, 0, rl.WHITE)
            }
            draw_intro_egg(egg_sprite, &intro, camera_px_x, camera_px_y)
        } else if eating_barrel != nil && rl.IsTextureValid(eat_sprite) {
            active_eat := eat_sprite
            if p.empowered && rl.IsTextureValid(mort_eat_sprite) { active_eat = mort_eat_sprite }
            eat_frame := min(BARREL_EAT_FRAMES-1, int(eating_barrel.eat_time/BARREL_EAT_FRAME_TIME))
            source := rl.Rectangle{f32(eat_frame*48), 0, 48, 32}
            sprite_x := int(render_x*CELL_SIZE)-camera_px_x-13
            if p.facing < 0 { source.width = -48; sprite_x -= 24*CELL_SIZE }
            destination := rl.Rectangle{f32(sprite_x), f32(int(render_y*CELL_SIZE)-camera_px_y-24), 48*CELL_SIZE, 32*CELL_SIZE}
            rl.DrawTexturePro(active_eat, source, destination, rl.Vector2{}, 0, dragon_tint)
        } else if rl.IsTextureValid(dragon_sprite) {
            active_sprite := dragon_sprite
            if p.empowered && rl.IsTextureValid(mort_sprite) { active_sprite = mort_sprite }
            if spit_state.mouth_time > 0 && rl.IsTextureValid(spit_sprite) {
                mouth_frame := min(3, int(spit_state.mouth_time/f32(0.07)))
                if animation == .Walk && rl.IsTextureValid(spit_run_sprite) {
                    active_sprite = spit_run_sprite
                    if p.empowered && rl.IsTextureValid(mort_spit_run_sprite) { active_sprite = mort_spit_run_sprite }
                    frame = mouth_frame*DINO_WALK_FRAMES+(frame-4)
                } else {
                    active_sprite = spit_sprite
                    if p.empowered && rl.IsTextureValid(mort_spit_sprite) { active_sprite = mort_spit_sprite }
                    frame = mouth_frame
                }
            } else if animation == .Air && rl.IsTextureValid(jump_sprite) {
                active_sprite = jump_sprite
                if p.empowered && rl.IsTextureValid(mort_jump_sprite) { active_sprite = mort_jump_sprite }
                frame = 0
                if p.vy >= 0 { frame = 1 }
            }
            source := rl.Rectangle{f32(frame*DINO_FRAME_SIZE), 0, DINO_FRAME_SIZE, DINO_FRAME_SIZE}
            if p.facing < 0 { source.width = -DINO_FRAME_SIZE }
            destination := rl.Rectangle{
                f32(int(render_x*CELL_SIZE)-camera_px_x-13),
                f32(int(render_y*CELL_SIZE)-camera_px_y-3),
                72, 72,
            }
            rl.DrawTexturePro(active_sprite, source, destination, rl.Vector2{}, 0, dragon_tint)
        }
        if intro.phase > .Hatching {
            draw_sandbox_menu(&sandbox_menu, material_icons)
            draw_player_hud(p.health, &inventory, material_icons, intro.inventory_visible)
            if intro.inventory_visible { draw_material_cursor(&inventory, material_icons, mouse_x, mouse_y) }
        }
        prompt_index := intro_prompt_index(intro.phase)
        if prompt_index >= 0 && intro.phase != .SlowMotion { draw_intro_prompt(intro_cards[prompt_index]) }
        if intro.phase == .SlowMotion {
            rl.DrawRectangle(0, 0, CANVAS_W, CANVAS_H, rl.Color{34, 79, 189, 76})
            if prompt_index >= 0 { draw_intro_prompt(intro_cards[prompt_index]) }
        }
        if dialogue.card != .None {
            sheet := dialogue_text[0]
            portrait := dragon_portrait
            switch dialogue.card {
            case .Awakening: sheet = dialogue_text[0]
            case .Knight: sheet = dialogue_text[1]; portrait = knight_portrait
            case .DragonShock: sheet = dialogue_text[2]
            case .KnightThreat: sheet = dialogue_text[3]; portrait = knight_portrait
            case .DragonVow: sheet = dialogue_text[4]
            case .BossQuestion: sheet = boss_dialogue_text[0]; portrait = boss_portrait
            case .BossAnswer: sheet = boss_dialogue_text[1]
            case .BossDefiance: sheet = boss_dialogue_text[2]
            case .BossFarewell: sheet = boss_dialogue_text[3]
            case .None:
            }
            draw_dialogue(&dialogue, sheet, portrait)
        }
        if game_over {
            rl.DrawRectangle(0, 0, VIEW_W*CELL_SIZE, VIEW_H*CELL_SIZE, rl.Color{7, 9, 16, 190})
            rl.DrawText("GAME OVER", c.int(VIEW_W*CELL_SIZE/2-123), c.int(VIEW_H*CELL_SIZE/2-24), 42, rl.WHITE)
        }
        rl.EndTextureMode()
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        if intro.phase == .SlowMotion && rl.IsShaderValid(slowmo_shader) { rl.BeginShaderMode(slowmo_shader) }
        draw_canvas(canvas, viewport)
        if intro.phase == .SlowMotion && rl.IsShaderValid(slowmo_shader) { rl.EndShaderMode() }
        rl.EndDrawing()
        when ODIN_OS == .JS { emscripten_sleep(16) }
    }
}
