package main

import "core:math"
import "core:c"
import rl "vendor:raylib"

SPRAY_MIN_SPEED :: f32(1.9) // cells per fixed tick
SPRAY_MAX_SPEED :: f32(3.1)
SPRAY_MIN_LIFE :: u16(36)
SPRAY_MAX_LIFE :: u16(42)
SOLID_FALL_GRAVITY :: f32(0.25) // cells per fixed tick squared
SOLID_MAX_FALL_SPEED :: f32(4)
SPIT_MOUTH_OPEN_TIME :: f32(0.21)
SPIT_CAPACITY :: 2048
SPRAY_PIXELS_PER_TICK :: 10
PLASMA_MIN_SPEED :: f32(5.5)
PLASMA_MAX_SPEED :: f32(7.5)
PLASMA_MIN_LIFE :: u16(28)
PLASMA_MAX_LIFE :: u16(34)
PLASMA_PENETRATION :: u8(10)

FlyingParticle :: struct {
    x, y, vx, vy: f32,
    material: Material,
    shade: u8,
    age: u16,
    life_ticks: u16,
    active: bool,
    settling: bool,
    penetration_left: u8,
    empowered: bool,
}

spit_random_unit :: proc(w: ^World) -> f32 {
    return f32(rand(w)%1000)/1000
}

SpitState :: struct {
    shots: [SPIT_CAPACITY]FlyingParticle,
    next_slot: int,
    mouth_time: f32,
}

selected_material :: proc(inventory: ^Inventory) -> Material {
    slot := inventory.slots[inventory.selected]
    if slot.count == 0 { return .Empty }
    return slot.material
}

spit_one :: proc(w: ^World, p: ^Player, inventory: ^Inventory, state: ^SpitState,
                 aim_x, aim_y: f32, offset: int) -> bool {
    material := selected_material(inventory)
    if material == .Empty { return false }
    p.facing = 1
    if aim_x < f32(p.x+PLAYER_W/2) { p.facing = -1 }
    mouth_x := p.x+PLAYER_W+1
    if p.facing < 0 { mouth_x = p.x-2 }
    mouth_y := p.y+8
    // The cartoon jaw extends past the body. Launch from its tip, but never
    // skip over a gate or enemy that stands between the body and the tip.
    tip_x := p.x+30
    if p.facing < 0 { tip_x = p.x-16 }
    for probe := mouth_x+p.facing; (p.facing > 0 && probe <= tip_x) ||
                                 (p.facing < 0 && probe >= tip_x); probe += p.facing {
        if !inside(probe, mouth_y) || kind_at(w, probe, mouth_y) != .Empty ||
           actor_occupies(w, probe, mouth_y) { break }
        mouth_x = probe
    }
    dx, dy := aim_x-f32(mouth_x), aim_y-f32(mouth_y)
    length := math.sqrt(dx*dx+dy*dy)
    if length < 0.01 { dx, dy, length = f32(p.facing), 0, 1 }
    direction_x, direction_y := dx/length, dy/length
    perpendicular_x, perpendicular_y := -direction_y, direction_x
    base_x := mouth_x+p.facing*int(math.round(4*math.abs(direction_y)))
    origin_x := base_x+int(math.round(perpendicular_x*f32(offset)))
    origin_y := mouth_y+int(math.round(perpendicular_y*f32(offset)))
    forward := f32(rand(w)%3)
    origin_x += int(math.round(direction_x*forward))
    origin_y += int(math.round(direction_y*forward))
    if !inside(origin_x, origin_y) || kind_at(w, origin_x, origin_y) != .Empty ||
       actor_occupies(w, origin_x, origin_y) { return false }

    for attempt in 0..<SPIT_CAPACITY {
        slot_index := (state.next_slot+attempt)%SPIT_CAPACITY
        shot := &state.shots[slot_index]
        if shot.active { continue }
        fan := (spit_random_unit(w)-0.5)*0.28
        speed := SPRAY_MIN_SPEED+spit_random_unit(w)*(SPRAY_MAX_SPEED-SPRAY_MIN_SPEED)
        life_ticks := SPRAY_MIN_LIFE+u16(rand(w)%u32(SPRAY_MAX_LIFE-SPRAY_MIN_LIFE+1))
        penetration_left: u8 = 0
        if material == .Plasma {
            fan = (spit_random_unit(w)-0.5)*0.025
            speed = PLASMA_MIN_SPEED+spit_random_unit(w)*(PLASMA_MAX_SPEED-PLASMA_MIN_SPEED)
            life_ticks = PLASMA_MIN_LIFE+u16(rand(w)%u32(PLASMA_MAX_LIFE-PLASMA_MIN_LIFE+1))
            penetration_left = PLASMA_PENETRATION
        }
        shot^ = FlyingParticle{
            x = f32(origin_x), y = f32(origin_y),
            vx = speed*(direction_x+perpendicular_x*fan),
            vy = speed*(direction_y+perpendicular_y*fan),
            material = material, shade = u8(rand(w)%4), life_ticks = life_ticks, active = true,
            penetration_left = penetration_left,
            empowered = p.empowered && material == .Fire,
        }
        state.next_slot = (slot_index+1)%SPIT_CAPACITY
        inventory_take(inventory, inventory.selected, 1)
        return true
    }
    return false
}

try_place_shot :: proc(w: ^World, shot: ^FlyingParticle, x, y: int) -> bool {
    if !inside(x, y) || actor_occupies(w, x, y) { return false }
    occupant := kind_at(w, x, y)
    if occupant != .Empty {
        if !solid(shot.material) || !mobile(occupant) ||
           !push_particle_out_body(w, x, y, x, y, .Particle, -1) { return false }
    }
    if kind_at(w, x, y) != .Empty { return false }
    place(w, x, y, shot.material)
    if kind_at(w, x, y) != shot.material { return false }
    w.cells[index(x, y)].shade = shot.shade
    return true
}

materialize_shot :: proc(w: ^World, shot: ^FlyingParticle, x, y: int) {
    length := math.sqrt(shot.vx*shot.vx+shot.vy*shot.vy)
    dx, dy: f32 = 0, 0
    if length > 0 { dx, dy = shot.vx/length, shot.vy/length }
    for retreat := 0; retreat <= 6; retreat += 1 {
        px := x-int(math.round(dx*f32(retreat)))
        py := y-int(math.round(dy*f32(retreat)))
        if try_place_shot(w, shot, px, py) {
            shot.active = false
            return
        }
    }
    if solid(shot.material) {
        // A full pocket may temporarily have nowhere to move its liquid.
        // Keep the solid in flight and retry instead of silently deleting it.
        shot.settling = true
        shot.vx, shot.vy = 0, 0
        shot.x, shot.y = f32(x), f32(y)
    } else {
        shot.active = false
    }
}

// Ordinary materials keep their horizontal momentum after the powered part of
// the spray ends. Gravity bends the path until they reach a surface.
update_flying_particles :: proc(w: ^World, state: ^SpitState) {
    for &shot in state.shots {
        if !shot.active { continue }
        shot.age += 1
        if shot.age >= shot.life_ticks && !shot.settling {
            if shot.material == .Fire || shot.material == .Plasma {
                shot.active = false
                continue
            }
            shot.settling = true
        }
        if shot.settling { shot.vy = min(SOLID_MAX_FALL_SPEED, shot.vy+SOLID_FALL_GRAVITY) }
        target_x, target_y := shot.x+shot.vx, shot.y+shot.vy
        current_x, current_y := int(shot.x), int(shot.y)
        goal_x, goal_y := int(target_x), int(target_y)
        distance_x, distance_y := abs(goal_x-current_x), -abs(goal_y-current_y)
        step_x, step_y := 1, 1
        if goal_x < current_x { step_x = -1 }
        if goal_y < current_y { step_y = -1 }
        error := distance_x+distance_y
        collided := false
        for current_x != goal_x || current_y != goal_y {
            next_x, next_y := current_x, current_y
            twice_error := 2*error
            if twice_error >= distance_y { error += distance_y; next_x += step_x }
            if twice_error <= distance_x { error += distance_x; next_y += step_y }
            if !inside(next_x, next_y) {
                shot.active = false
                collided = true
                break
            }
            if damage_enemy_from_projectile(w, next_x, next_y, shot.material, shot.empowered) {
                shot.active = false
                collided = true
                break
            }
            target := kind_at(w, next_x, next_y)
            if shot.material == .Fire && (target == .Powder || target == .Petrol) {
                place(w, next_x, next_y, .Boom)
                shot.active = false
                collided = true
                break
            }
            if shot.material == .Plasma && actor_occupies(w, next_x, next_y) {
                shot.active = false
                collided = true
                break
            }
            if shot.material == .Plasma && target != .Empty {
                if shot.penetration_left == 0 { shot.penetration_left = PLASMA_PENETRATION }
                place(w, next_x, next_y, .Empty)
                shot.penetration_left -= 1
                if shot.penetration_left == 0 {
                    shot.active = false
                    collided = true
                    break
                }
                current_x, current_y = next_x, next_y
                continue
            }
            if actor_occupies(w, next_x, next_y) ||
               (target != .Empty && (!solid(shot.material) || solid(target))) {
                materialize_shot(w, &shot, current_x, current_y)
                collided = true
                break
            }
            current_x, current_y = next_x, next_y
        }
        if collided { continue }
        shot.x, shot.y = target_x, target_y
    }
}

spit_tick :: proc(w: ^World, p: ^Player, inventory: ^Inventory,
                  state: ^SpitState, aim_x, aim_y: f32, held: bool) -> int {
    emitted := 0
    can_spit := held && selected_material(inventory) != .Empty
    if can_spit {
        count := SPRAY_PIXELS_PER_TICK
        if p.empowered && selected_material(inventory) == .Fire { count *= 2 }
        for _ in 0..<count {
            offset := int(rand(w)%9)-4
            if selected_material(inventory) == .Plasma { offset = int(rand(w)%3)-1 }
            if spit_one(w, p, inventory, state, aim_x, aim_y, offset) { emitted += 1 }
        }
    }
    if can_spit {
        state.mouth_time = min(SPIT_MOUTH_OPEN_TIME, state.mouth_time+PHYSICS_DT)
    } else {
        state.mouth_time = max(0, state.mouth_time-PHYSICS_DT)
    }
    update_flying_particles(w, state)
    return emitted
}

draw_flying_particles :: proc(state: ^SpitState, camera_px_x, camera_px_y: int) {
    for shot in state.shots {
        if !shot.active { continue }
        x := int(shot.x*f32(CELL_SIZE))-camera_px_x
        y := int(shot.y*f32(CELL_SIZE))-camera_px_y
        if shot.material == .Fire {
            glow_size := CELL_SIZE*2
            glow_color := rl.Color{255, 85, 20, 75}
            if shot.empowered { glow_size = CELL_SIZE*3; glow_color = rl.Color{255, 48, 10, 105} }
            rl.DrawRectangle(c.int(x-(glow_size-CELL_SIZE)/2), c.int(y-(glow_size-CELL_SIZE)/2),
                             c.int(glow_size), c.int(glow_size), glow_color)
        }
        rl.DrawRectangle(c.int(x), c.int(y), CELL_SIZE, CELL_SIZE,
                         palette[shot.material][shot.shade])
    }
}
