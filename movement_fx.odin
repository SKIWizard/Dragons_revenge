package main

import rl "vendor:raylib"
import "core:c"

FX_CAPACITY :: 192
RUN_DUST_INTERVAL :: f32(0.075)

MovementParticle :: struct {
    x, y, vx, vy: f32,
    life, max_life: f32,
    color: rl.Color,
    size: int,
}

MovementFX :: struct {
    particles: [FX_CAPACITY]MovementParticle,
    next_slot: int,
    random_state: u32,
    run_timer: f32,
    last_direction: int,
}

MovementEvent :: enum {Run, Jump, Land, Turn}

fx_random :: proc(fx: ^MovementFX) -> u32 {
    fx.random_state = fx.random_state*1664525+1013904223
    return fx.random_state
}

fx_range :: proc(fx: ^MovementFX, low, high: f32) -> f32 {
    fraction := f32(fx_random(fx)%1000)/1000
    return low+(high-low)*fraction
}

movement_surface :: proc(w: ^World, p: ^Player) -> Material {
    foot_y := p.y+PLAYER_H-1
    // Water at the feet creates droplets even when stone supports the player.
    for x := p.x+3; x < p.x+PLAYER_W-3; x += 1 {
        if kind_at(w, x, foot_y) == .Water { return .Water }
    }
    for gap := 0; gap <= GROUND_PROBE_DISTANCE; gap += 1 {
        y := p.y+PLAYER_H+gap
        for x := p.x; x < p.x+PLAYER_W; x += 1 {
            kind := kind_at(w, x, y)
            if solid(kind) || powder(kind) { return kind }
        }
    }
    return .Stone
}

emit_movement_particles :: proc(fx: ^MovementFX, p: ^Player, surface: Material, event: MovementEvent, momentum: int) {
    amount := 2
    if event == .Jump { amount = 7 }
    if event == .Land { amount = 9 }
    if event == .Turn { amount = 11 }
    for _ in 0..<amount {
        slot := &fx.particles[fx.next_slot]
        fx.next_slot = (fx.next_slot+1)%FX_CAPACITY
        slot.x = f32(p.x+PLAYER_W/2)+fx_range(fx, -5, 5)
        slot.y = f32(p.y+PLAYER_H-1)+fx_range(fx, -1, 1)
        spread := f32(momentum)
        if event == .Jump || event == .Land { spread = 0 }
        slot.vx = spread*fx_range(fx, 35, 85)+fx_range(fx, -45, 45)
        slot.vy = fx_range(fx, -90, -35)
        if event == .Run { slot.vy = fx_range(fx, -58, -22) }
        if event == .Turn {
            slot.vx = spread*fx_range(fx, 55, 125)+fx_range(fx, -30, 30)
            slot.vy = fx_range(fx, -110, -45)
        }
        if event == .Land { slot.vx = fx_range(fx, -105, 105) }
        if surface == .Water { slot.vy -= 35 }
        slot.max_life = fx_range(fx, 0.18, 0.36)
        if event == .Turn || event == .Land { slot.max_life += 0.08 }
        slot.life = slot.max_life
        slot.color = palette[surface][int(fx_random(fx)%4)]
        slot.size = 1
        if fx_random(fx)%5 == 0 { slot.size = 2 }
    }
}

update_movement_fx :: proc(fx: ^MovementFX, w: ^World, p: ^Player,
                           old_x, old_y: int, old_vx, old_vy: f32, was_grounded: bool, input_direction: int) {
    for &particle in fx.particles {
        if particle.life <= 0 { continue }
        particle.life -= PHYSICS_DT
        if particle.life <= 0 { continue }
        particle.vy += 360*PHYSICS_DT
        particle.vx *= 0.96
        particle.x += particle.vx*PHYSICS_DT
        particle.y += particle.vy*PHYSICS_DT
    }
    if fx.run_timer > 0 { fx.run_timer -= PHYSICS_DT }
    surface := movement_surface(w, p)
    if old_vy >= 0 && p.vy < 0 {
        takeoff := p^
        takeoff.y = old_y
        emit_movement_particles(fx, &takeoff, movement_surface(w, &takeoff), .Jump, 0)
        fx.run_timer = RUN_DUST_INTERVAL
    } else if !was_grounded && p.grounded {
        emit_movement_particles(fx, p, surface, .Land, 0)
        fx.run_timer = RUN_DUST_INTERVAL
    }
    if input_direction != 0 && input_direction != fx.last_direction &&
       was_grounded && old_vx*f32(input_direction) < -45 {
        momentum := 1
        if old_vx < 0 { momentum = -1 }
        emit_movement_particles(fx, p, surface, .Turn, momentum)
        fx.run_timer = RUN_DUST_INTERVAL
    }
    if input_direction != 0 { fx.last_direction = input_direction }
    if p.grounded && p.x != old_x && (p.vx > 55 || p.vx < -55) && fx.run_timer <= 0 {
        momentum := -1
        if p.vx < 0 { momentum = 1 }
        emit_movement_particles(fx, p, surface, .Run, momentum)
        fx.run_timer = RUN_DUST_INTERVAL
    }
}

draw_movement_fx :: proc(fx: ^MovementFX, camera_px_x, camera_px_y: int) {
    for particle in fx.particles {
        if particle.life <= 0 { continue }
        color := particle.color
        color.a = u8(230*particle.life/particle.max_life)
        screen_x := int(particle.x*f32(CELL_SIZE))-camera_px_x
        screen_y := int(particle.y*f32(CELL_SIZE))-camera_px_y
        rl.DrawRectangle(c.int(screen_x), c.int(screen_y), c.int(particle.size*CELL_SIZE), c.int(particle.size*CELL_SIZE), color)
    }
}
