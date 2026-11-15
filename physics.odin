package main

MaterialState :: enum { Empty, Static, Powder, Liquid, Gas }
MaterialProps :: struct {
    state: MaterialState,
    density: i16,
    gravity, max_speed: f32, // cells per fixed tick
    flow_chance, slide_chance: u8, // percent
    ignition_temp, melt_temp, boil_temp: i16,
}

material_props := [Material]MaterialProps{
    .Empty  = {.Empty, 0, 0, 0, 0, 0, 0, 0, 0},
    .Sand   = {.Powder, 90, 0.25, 4, 0, 95, 0, 0, 0},
    .Water  = {.Liquid, 30, 0, 0, 0, 0, 0, 0, 100},
    .Stone  = {.Static, 120, 0, 0, 0, 0, 0, 1200, 0},
    .Smoke  = {.Gas, 5, -0.10, 2, 55, 0, 500, 0, 0},
    .Wood   = {.Static, 100, 0, 0, 0, 0, 150, 0, 0},
    .Fire   = {.Gas, 3, -0.18, 2, 70, 0, 0, 0, 0},
    .Steam  = {.Gas, 4, -0.20, 3, 90, 0, 0, 0, 0},
    .Plasma = {.Gas, 2, -0.22, 3, 95, 0, 0, 0, 0},
    .Lava   = {.Liquid, 110, 0, 0, 0, 0, 0, 0, 0},
    .Powder = {.Powder, 80, 0.25, 4, 0, 90, 85, 0, 0},
    .Boom   = {.Gas, 1, -0.15, 3, 100, 0, 0, 0, 0},
    .Petrol = {.Liquid, 20, 0, 0, 0, 0, 80, 0, 0},
    .Acid   = {.Liquid, 32, 0, 0, 0, 0, 0, 0, 120},
    .Iron   = {.Static, 130, 0, 0, 0, 0, 0, 1500, 0},
    .Snow   = {.Powder, 65, 0.12, 2, 0, 45, 0, 5, 0},
    .KnightDebris = {.Powder, 70, 0.25, 4, 0, 80, 0, 0, 0},
    .OgreDebris = {.Powder, 70, 0.25, 4, 0, 80, 0, 0, 0},
    .Ground = {.Static, 105, 0, 0, 0, 0, 0, 1200, 0},
    .Grass = {.Static, 95, 0, 0, 0, 0, 150, 0, 0},
    .Glass = {.Static, 115, 0, 0, 0, 0, 0, 1000, 0},
    .Blood = {.Liquid, 32, 0, 0, 0, 0, 0, 0, 0},
    .Potion = {.Liquid, 30, 0, 0, 0, 0, 0, 0, 0},
}

props :: proc(k: Material) -> MaterialProps { return material_props[k] }
solid :: proc(k: Material) -> bool { return props(k).state == .Static }
powder :: proc(k: Material) -> bool { return props(k).state == .Powder }
liquid :: proc(k: Material) -> bool { return props(k).state == .Liquid }
gas :: proc(k: Material) -> bool { return props(k).state == .Gas }
mobile :: proc(k: Material) -> bool { return powder(k) || liquid(k) || gas(k) }
flammable :: proc(k: Material) -> bool { return k == .Wood || k == .Grass || k == .Petrol || k == .Powder }
dissolvable :: proc(k: Material) -> bool { return k == .Stone || k == .Wood || k == .Iron || k == .Sand || k == .Ground || k == .Grass }

rand :: proc(w: ^World) -> u32 {
    w.random_state = w.random_state*1664525+1013904223
    return w.random_state
}
chance :: proc(w: ^World, percent: u8) -> bool { return rand(w)%100 < u32(percent) }

wake :: proc(w: ^World, x, y: int) {
    if !inside(x, y) { return }
    i := index(x, y)
    generation := w.tick+1
    if w.queued_for[i] == generation { return }
    w.queued_for[i] = generation
    if w.stepping {
        if w.current_b { w.active_a[w.next_count] = i32(i) } else { w.active_b[w.next_count] = i32(i) }
        w.next_count += 1
    } else {
        if w.current_b { w.active_b[w.active_count] = i32(i) } else { w.active_a[w.active_count] = i32(i) }
        w.active_count += 1
    }
}

wake_neighbors :: proc(w: ^World, x, y: int) {
    for dy := -1; dy <= 1; dy += 1 {
        for dx := -1; dx <= 1; dx += 1 {
            nx, ny := x+dx, y+dy
            if !inside(nx, ny) { continue }
            k := w.cells[index(nx, ny)].kind
            if mobile(k) || w.cells[index(nx, ny)].burning { wake(w, nx, ny) }
        }
    }
}

make_cell :: proc(w: ^World, kind: Material) -> Cell {
    c := Cell{kind = kind, shade = u8(rand(w)>>30), temperature = 20, health = 10, origin = kind}
    #partial switch kind {
    case .Fire: c.life = i16(15+rand(w)%31); c.temperature = 320
    case .Smoke: c.life = i16(90+rand(w)%91); c.temperature = 80
    case .Steam: c.life = i16(240+rand(w)%241); c.temperature = 135
    case .Plasma: c.life = i16(20+rand(w)%21); c.temperature = 1800
    case .Lava: c.temperature = 950
    case .Boom: c.life = 8; c.temperature = 600
    case .Snow: c.temperature = -10
    case .KnightDebris, .OgreDebris, .Blood, .Potion: c.life = i16(130+rand(w)%130)
    case .Acid: c.life = i16(90+rand(w)%61)
    }
    c.max_life = c.life
    return c
}

place :: proc(w: ^World, x, y: int, kind: Material) {
    if !inside(x, y) { return }
    if mobile(kind) && actor_occupies(w, x, y) { return }
    i := index(x, y)
    w.cells[i] = make_cell(w, kind)
    if w.stepping { w.cells[i].updated = w.tick }
    if mobile(kind) { wake(w, x, y) }
    wake_neighbors(w, x, y)
}

kind_at :: proc(w: ^World, x, y: int) -> Material {
    if !inside(x, y) { return .Stone }
    return w.cells[index(x, y)].kind
}

swap_cells :: proc(w: ^World, x, y, nx, ny: int) {
    a, b := index(x, y), index(nx, ny)
    w.cells[a], w.cells[b] = w.cells[b], w.cells[a]
    w.cells[a].updated, w.cells[b].updated = w.tick, w.tick
    wake_neighbors(w, x, y)
    wake_neighbors(w, nx, ny)
}

try_move :: proc(w: ^World, x, y, nx, ny: int) -> bool {
    if !inside(nx, ny) { return false }
    if actor_occupies(w, nx, ny) { return false }
    moving := w.cells[index(x, y)].kind
    target := w.cells[index(nx, ny)].kind
    if target == moving || solid(target) { return false }
    if target != .Empty {
        if ny == y { return false } // density never causes horizontal jitter
        if ny > y && props(moving).density <= props(target).density { return false }
        if ny < y && props(moving).density >= props(target).density { return false }
    }
    swap_cells(w, x, y, nx, ny)
    return true
}

can_enter :: proc(w: ^World, x, y, nx, ny: int) -> bool {
    if !inside(nx, ny) { return false }
    if actor_occupies(w, nx, ny) { return false }
    moving, target := kind_at(w, x, y), kind_at(w, nx, ny)
    if target == .Empty { return true }
    if target == moving || solid(target) || ny == y { return false }
    if ny > y { return props(moving).density > props(target).density }
    return props(moving).density < props(target).density
}

has_open_path :: proc(w: ^World, x, y: int) -> bool {
    k := kind_at(w, x, y)
    if powder(k) {
        return can_enter(w, x, y, x, y+1) || can_enter(w, x, y, x-1, y+1) || can_enter(w, x, y, x+1, y+1)
    }
    if liquid(k) {
        return can_enter(w, x, y, x, y+1) ||
               kind_at(w, x-1, y) == .Empty || kind_at(w, x+1, y) == .Empty
    }
    return false
}

move_one :: proc(w: ^World, x, y: ^int, dx, dy: int) -> bool {
    if !try_move(w, x^, y^, x^+dx, y^+dy) { return false }
    x^ += dx
    y^ += dy
    return true
}

preferred_direction :: proc(w: ^World, cell: ^Cell) -> int {
    if cell.vx > 0 { return 1 }
    if cell.vx < 0 { return -1 }
    if rand(w)&1 == 0 { return -1 }
    return 1
}

move_powder :: proc(w: ^World, x, y: ^int) -> bool {
    cell := &w.cells[index(x^, y^)]
    p := props(cell.kind)
    cell.vy = min(cell.vy+p.gravity, p.max_speed)
    cell.travel += cell.vy
    steps := int(cell.travel)
    cell.travel -= f32(steps)
    moved := false
    for _ in 0..<steps {
        if move_one(w, x, y, 0, 1) { moved = true; continue }
        direction := preferred_direction(w, &w.cells[index(x^, y^)]) 
        if chance(w, p.slide_chance) &&
           (move_one(w, x, y, direction, 1) || move_one(w, x, y, -direction, 1)) { moved = true }
        w.cells[index(x^, y^)].vy = 0
        w.cells[index(x^, y^)].travel = 0
        break
    }
    return moved
}

// Fresh remains keep their launch momentum for a few ticks, checking every
// crossed cell. Afterwards blood flows and fragments settle normally.
move_scattered :: proc(w: ^World, x, y: ^int) -> bool {
    cell := &w.cells[index(x^, y^)]
    cell.scatter_ticks -= 1
    cell.vy = min(cell.vy+0.26, 3.5)
    cell.vx *= 0.97
    cell.scatter_x += cell.vx
    cell.scatter_y += cell.vy
    steps_x := int(cell.scatter_x)
    steps_y := int(cell.scatter_y)
    cell.scatter_x -= f32(steps_x)
    cell.scatter_y -= f32(steps_y)
    moved := false
    step_x := 1
    if steps_x < 0 { step_x = -1; steps_x = -steps_x }
    for _ in 0..<steps_x {
        if move_one(w, x, y, step_x, 0) { moved = true }
        else { w.cells[index(x^, y^)].vx = 0; break }
    }
    step_y := 1
    if steps_y < 0 { step_y = -1; steps_y = -steps_y }
    for _ in 0..<steps_y {
        if move_one(w, x, y, 0, step_y) { moved = true }
        else { w.cells[index(x^, y^)].vy = 0; break }
    }
    return moved
}

acid_contact :: proc(w: ^World, x, y: int) -> bool {
    return dissolvable(kind_at(w, x, y+1)) ||
           dissolvable(kind_at(w, x-1, y)) ||
           dissolvable(kind_at(w, x+1, y))
}

move_liquid :: proc(w: ^World, x, y: ^int) -> bool {
    if kind_at(w, x^, y^) == .Acid && acid_contact(w, x^, y^) { return false }
    if move_one(w, x, y, 0, 1) { return true }
    direction := -1
    if rand(w)&1 == 0 { direction = 1 }
    if move_one(w, x, y, direction, 0) { return true }
    return move_one(w, x, y, -direction, 0)
}

move_gas :: proc(w: ^World, x, y: ^int) -> bool {
    cell := &w.cells[index(x^, y^)]
    p := props(cell.kind)
    if cell.kind == .Fire && kind_at(w, x^, y^+1) == .Wood { return false }
    cell.vy = max(cell.vy+p.gravity, -p.max_speed)
    cell.travel += -cell.vy
    steps := int(cell.travel)
    cell.travel -= f32(steps)
    direction := preferred_direction(w, cell)
    moved := false
    for _ in 0..<steps {
        if move_one(w, x, y, 0, -1) ||
           move_one(w, x, y, direction, -1) ||
           move_one(w, x, y, -direction, -1) { moved = true; continue }
        break
    }
    if moved { return true }
    if chance(w, p.flow_chance) &&
       (move_one(w, x, y, direction, 0) || move_one(w, x, y, -direction, 0)) {
        w.cells[index(x^, y^)].vx = f32(direction)
        return true
    }
    return false
}

spawn_blast_sparks :: proc(w: ^World, x, y: int) {
    directions := [16][2]f32{
        {1, 0}, {2, 1}, {1, 1}, {1, 2}, {0, 1}, {-1, 2}, {-1, 1}, {-2, 1},
        {-1, 0}, {-2, -1}, {-1, -1}, {-1, -2}, {0, -1}, {1, -2}, {1, -1}, {2, -1},
    }
    for direction in directions {
        for _ in 0..<3 {
            if w.blast_spark_count >= MAX_BLAST_SPARKS { return }
            speed := f32(25+rand(w)%38)/10
            variation := f32(int(rand(w)%11)-5)/10
            life := u8(10+rand(w)%16)
            w.blast_sparks[w.blast_spark_count] = Blast_Spark{
                x = f32(x)+0.5, y = f32(y)+0.5,
                vx = direction[0]*speed+variation,
                vy = direction[1]*speed-variation,
                life = life, max_life = life, shade = u8(rand(w)%4),
            }
            w.blast_spark_count += 1
        }
    }
}

step_blast_sparks :: proc(w: ^World) {
    n := 0
    for i := 0; i < w.blast_spark_count; i += 1 {
        spark := w.blast_sparks[i]
        if spark.life <= 1 { continue }
        spark.life -= 1
        spark.x += spark.vx
        spark.y += spark.vy
        spark.vx *= 0.94
        spark.vy = spark.vy*0.94+0.09
        w.blast_sparks[n] = spark
        n += 1
    }
    w.blast_spark_count = n
}

blast :: proc(w: ^World, x, y: int) {
    tile := (y/BLAST_TILE)*BLAST_COLS+x/BLAST_TILE
    last := w.blast_ticks[tile]
    if last != 0 && w.tick-last < 5 { return }
    w.blast_ticks[tile] = w.tick
    w.blast_events += 1
    spawn_blast_sparks(w, x, y)

    RADIUS :: 20
    for dy := -RADIUS; dy <= RADIUS; dy += 1 {
        for dx := -RADIUS; dx <= RADIUS; dx += 1 {
            distance_sq := dx*dx+dy*dy
            if distance_sq > RADIUS*RADIUS { continue }
            nx, ny := x+dx, y+dy
            if !inside(nx, ny) { continue }
            kind := kind_at(w, nx, ny)
            if kind == .Powder || kind == .Petrol {
                place(w, nx, ny, .Boom)
                continue
            }
            if kind == .Boom { continue }
            // The inner blast cuts a passage through wood; stone and iron resist it.
            strength := (RADIUS*RADIUS-distance_sq)*100/(RADIUS*RADIUS)
            destroy := false
            #partial switch kind {
            case .Wood: destroy = distance_sq <= 9*9 || chance(w, u8(20+strength*75/100))
            case .Stone: destroy = chance(w, u8(3+strength*50/100))
            case .Ground: destroy = chance(w, u8(5+strength*58/100))
            case .Grass: destroy = chance(w, u8(18+strength*70/100))
            case .Glass: destroy = chance(w, u8(25+strength*70/100))
            case .Iron: destroy = chance(w, u8(1+strength*22/100))
            case .Empty: if strength > 25 && chance(w, u8(5+strength/9)) { place(w, nx, ny, .Fire) }
            case .Fire, .Plasma: // Flames survive the shockwave.
            case: destroy = chance(w, u8(12+strength*70/100))
            }
            if destroy {
                place(w, nx, ny, .Empty)
                continue
            }
            if mobile(kind) && kind != .Fire && kind != .Plasma && distance_sq > 0 {
                push_dx, push_dy := 0, 0
                if dx > 0 { push_dx = 1 } else if dx < 0 { push_dx = -1 }
                if dy > 0 { push_dy = 1 } else if dy < 0 { push_dy = -1 }
                push_x := nx+push_dx
                push_y := ny+push_dy
                if inside(push_x, push_y) && kind_at(w, push_x, push_y) == .Empty &&
                   !actor_occupies(w, push_x, push_y) {
                    swap_cells(w, nx, ny, push_x, push_y)
                    wake(w, push_x, push_y)
                }
            }
        }
    }
}

heat_neighbours :: proc(w: ^World, x, y: int) {
    i := index(x, y)
    offsets := [4][2]int{{0,-1}, {1,0}, {0,1}, {-1,0}}
    for offset in offsets {
        nx, ny := x+offset[0], y+offset[1]
        if !inside(nx, ny) { continue }
        n := index(nx, ny)
        if w.cells[n].kind == .Empty { continue }
        difference := w.cells[i].temperature-w.cells[n].temperature
        if difference > -8 && difference < 8 { continue }
        divisor: i32 = 8
        if w.cells[i].kind == .Iron || w.cells[n].kind == .Iron { divisor = 4 }
        transfer := difference/divisor
        if w.cells[i].kind == .Lava || w.cells[n].kind == .Lava {
            transfer = min(3, max(-3, transfer))
        }
        w.cells[n].temperature += transfer
        w.cells[i].temperature -= transfer
        wake(w, nx, ny)
    }
}

react_cell :: proc(w: ^World, x, y: int) {
    i := index(x, y)
    k := w.cells[i].kind
    if k == .Empty { return }
    if k == .Fire { w.cells[i].temperature = 320 }
    if k == .Plasma { w.cells[i].temperature = 1800 }
    if k == .Lava && w.cells[i].temperature < 400 {
        origin := w.cells[i].origin
        if origin == .Iron { place(w, x, y, .Iron) } else { place(w, x, y, .Stone) }
        return
    }
    heat_neighbours(w, x, y)
    if w.cells[i].temperature > 20 && k != .Fire && k != .Plasma && k != .Lava {
        w.cells[i].temperature -= max(1, (w.cells[i].temperature-20)/60)
    }
    if w.cells[i].health <= 0 { place(w, x, y, .Empty); return }

    if k == .KnightDebris || k == .OgreDebris || k == .Blood || k == .Potion {
        w.cells[i].life -= 1
        if w.cells[i].life <= 0 { place(w, x, y, .Empty); return }
    }

    if k == .Plasma {
        // Free plasma uses the same ten-cell erosion budget as a fired bolt.
        offsets := [4][2]int{{0,-1}, {1,0}, {0,1}, {-1,0}}
        for offset in offsets {
            nx, ny := x+offset[0], y+offset[1]
            if !inside(nx, ny) { continue }
            other := kind_at(w, nx, ny)
            if other == .Empty || other == .Plasma { continue }
            place(w, nx, ny, .Empty)
            w.cells[i].health -= 1
            if w.cells[i].health <= 0 { place(w, x, y, .Empty); return }
            break
        }
    }

    if k == .Acid {
        // Acid sealed in glass can be stored indefinitely. Contact with
        // dissolvable terrain starts a short, consumable reaction.
        if acid_contact(w, x, y) { w.cells[i].burn_progress = 1 }
        if w.cells[i].burn_progress > 0 {
            w.cells[i].life -= 1
            if w.cells[i].life <= 0 { place(w, x, y, .Empty); return }
        }
        if w.tick%2 == 0 {
            offsets := [3][2]int{{0,1}, {-1,0}, {1,0}}
            for offset in offsets {
                nx, ny := x+offset[0], y+offset[1]
                if !inside(nx, ny) || !dissolvable(kind_at(w, nx, ny)) { continue }
                n := index(nx, ny)
                w.cells[n].health -= 1
                w.cells[i].life -= 4
                wake(w, nx, ny)
                break
            }
        }
    }
    if k == .Lava {
        offsets := [4][2]int{{0,-1}, {1,0}, {0,1}, {-1,0}}
        for offset in offsets {
            nx, ny := x+offset[0], y+offset[1]
            if !inside(nx, ny) { continue }
            other := kind_at(w, nx, ny)
            if other == .Wood || other == .Grass {
                neighbour := &w.cells[index(nx, ny)]
                neighbour.temperature = max(neighbour.temperature, i32(180))
                neighbour.burning = true
                wake(w, nx, ny)
            } else if liquid(other) && other != .Lava {
                if other == .Petrol { place(w, nx, ny, .Boom) }
                else { place(w, nx, ny, .Steam) }
                w.cells[i].temperature -= 3
            }
        }
        if w.tick%4 == 0 { w.cells[i].temperature -= 1 }
    }
    if k == .Fire {
        offsets := [4][2]int{{0,-1}, {1,0}, {0,1}, {-1,0}}
        for offset in offsets {
            nx, ny := x+offset[0], y+offset[1]
            if !inside(nx, ny) { continue }
            other := kind_at(w, nx, ny)
            if other == .Water {
                place(w, x, y, .Smoke)
                place(w, nx, ny, .Steam)
                return
            }
            if other == .Wood || other == .Grass { w.cells[index(nx, ny)].temperature += 22; wake(w, nx, ny) }
            if other == .Powder || other == .Petrol {
                place(w, nx, ny, .Boom)
            }
        }
    }
    if k == .Wood || k == .Grass {
        if w.cells[i].temperature >= i32(props(k).ignition_temp) { w.cells[i].burning = true }
        if w.cells[i].burning {
            w.cells[i].temperature = max(w.cells[i].temperature, 180)
            w.cells[i].burn_progress += 2
            if w.tick%5 == 0 {
                nx, ny := x, y-1
                if inside(nx, ny) && kind_at(w, nx, ny) == .Empty { place(w, nx, ny, .Fire) }
            }
            if w.cells[i].burn_progress >= 100 {
                if k == .Grass { place(w, x, y, .Ground) }
                else { place(w, x, y, .Smoke) }
                return
            }
        }
    }
    if k == .Boom && w.cells[i].burn_progress == 0 {
        blast(w, x, y)
        w.cells[i].burn_progress = 1
    }
    #partial switch k {
    case .Water: if w.cells[i].temperature >= i32(props(k).boil_temp) { place(w, x, y, .Steam); return }
    case .Steam:
        age := w.cells[i].max_life-w.cells[i].life
        if w.cells[i].life <= 0 ||
           (age > 120 && w.cells[i].temperature <= 85 && chance(w, 3)) {
            origin := w.cells[i].origin
            if origin == .Acid { place(w, x, y, .Acid) } else { place(w, x, y, .Water) }
            return
        }
    case .Snow: if w.cells[i].temperature >= i32(props(k).melt_temp) { place(w, x, y, .Water); return }
    case .Petrol: if w.cells[i].temperature >= i32(props(k).ignition_temp) { place(w, x, y, .Boom); return }
    case .Powder: if w.cells[i].temperature >= i32(props(k).ignition_temp) { place(w, x, y, .Boom); return }
    case .Iron: if w.cells[i].temperature >= i32(props(k).melt_temp) { place(w, x, y, .Lava); w.cells[i].origin = .Iron; return }
    case .Stone: if w.cells[i].temperature >= i32(props(k).melt_temp) { place(w, x, y, .Lava); return }
    case .Acid: if w.cells[i].temperature >= i32(props(k).boil_temp) { place(w, x, y, .Steam); w.cells[i].origin = .Acid; return }
    case .Smoke: if w.cells[i].temperature >= i32(props(k).ignition_temp) { place(w, x, y, .Fire); return }
    }
    if gas(k) {
        w.cells[i].life -= 1
        if w.cells[i].life <= 0 {
            if k == .Fire && chance(w, 65) { place(w, x, y, .Smoke) }
            else if k != .Steam { place(w, x, y, .Empty) }
        }
    }
}

step_world :: proc(w: ^World) {
    w.tick += 1
    step_blast_sparks(w)
    w.stepping = true
    for n := 0; n < w.active_count; n += 1 {
        i := int(w.active_a[n])
        if w.current_b { i = int(w.active_b[n]) }
        if w.cells[i].kind == .Empty || w.cells[i].updated == w.tick { continue }
        x, y := i%WORLD_W, i/WORLD_W
        k := w.cells[i].kind
        if solid(k) && w.cells[i].temperature == 20 && !w.cells[i].burning && w.cells[i].health == 10 { continue }
        w.cells[i].updated = w.tick
        react_cell(w, x, y)
        if w.cells[i].kind != k { continue } // transformed particles wait for the next tick
        moved := false
        if w.cells[i].scatter_ticks > 0 {
            moved = move_scattered(w, &x, &y)
        } else {
            if powder(k) { moved = move_powder(w, &x, &y) }
            if liquid(k) { moved = move_liquid(w, &x, &y) }
            if gas(k) { moved = move_gas(w, &x, &y) }
        }
        cell := &w.cells[index(x, y)]
        if moved { cell.rest_ticks = 0 }
        else if cell.rest_ticks < 255 { cell.rest_ticks += 1 }
        if gas(k) || k == .KnightDebris || k == .OgreDebris || k == .Blood || k == .Potion ||
           cell.scatter_ticks > 0 || cell.burning || cell.temperature != 20 || has_open_path(w, x, y) ||
           (k == .Acid && acid_contact(w, x, y)) ||
           (mobile(k) && cell.rest_ticks < 8) { wake(w, x, y) }
    }
    w.stepping = false
    w.active_count = w.next_count
    w.next_count = 0
    w.current_b = !w.current_b
}
