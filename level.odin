package main

MAX_LEVEL_BARRELS :: 24
MAX_LEVEL_HOUSES :: 12
MAX_LEVEL_VESSELS :: 12
GRASS_DEPTH :: 2
SOIL_DEPTH :: 18

BARREL_CONTENTS := [15]Material{
    .Sand, .Water, .Stone, .Smoke, .Wood, .Steam, .Plasma,
    .Lava, .Powder, .Boom, .Petrol, .Acid, .Iron, .Snow, .Potion,
}
// Matching weights: explosive fuel is common, static building materials are rare.
BARREL_WEIGHTS := [15]u32{
    3, 7, 1, 3, 1, 3, 12,
    4, 25, 3, 25, 12, 1, 7, 5,
}

choose_barrel_material :: proc(seed: ^u32) -> Material {
    total: u32 = 0
    for weight in BARREL_WEIGHTS { total += weight }
    roll := level_random(seed)%total
    for weight, i in BARREL_WEIGHTS {
        if roll < weight { return BARREL_CONTENTS[i] }
        roll -= weight
    }
    unreachable()
}

House :: struct {
    x, y, width, height, roof_height: int,
}

Vessel :: struct {
    x, y, width, height: int,
    material: Material,
}

Level :: struct {
    terrain: [WORLD_W]int,
    barrels: [MAX_LEVEL_BARRELS]Barrel,
    barrel_count: int,
    houses: [MAX_LEVEL_HOUSES]House,
    house_count: int,
    vessels: [MAX_LEVEL_VESSELS]Vessel,
    vessel_count: int,
}

level_random :: proc(seed: ^u32) -> u32 {
    seed^ = seed^*1664525+1013904223
    return seed^
}

generate_terrain :: proc(level: ^Level, seed: ^u32) {
    // A safe, level spawn area blends into broad rolling hills. Gentle slopes
    // stay within the player's four-cell step-up allowance.
    for x := 0; x < 120; x += 1 { level.terrain[x] = FLOOR_Y }
    left, start_y := 120, FLOOR_Y
    for left < WORLD_W {
        right := min(WORLD_W, left+32+int(level_random(seed)%27))
        end_y := FLOOR_Y-13+int(level_random(seed)%27)
        for x := left; x < right; x += 1 {
            t := f32(x-left)/f32(right-left)
            smooth := t*t*(3-2*t)
            level.terrain[x] = int(f32(start_y)+f32(end_y-start_y)*smooth+0.5)
        }
        left, start_y = right, end_y
    }
}

flatten_terrain :: proc(level: ^Level, requested_left, requested_right: int) -> int {
    left := max(0, requested_left)
    right := min(WORLD_W, requested_right)
    surface := level.terrain[(left+right)/2]
    ramp := 18
    for x := max(0, left-ramp); x < left; x += 1 {
        t := f32(x-(left-ramp))/f32(ramp)
        level.terrain[x] = int(f32(level.terrain[x])*(1-t)+f32(surface)*t+0.5)
    }
    for x := left; x < right; x += 1 { level.terrain[x] = surface }
    for x := right; x < min(WORLD_W, right+ramp); x += 1 {
        t := f32((right+ramp)-x)/f32(ramp)
        level.terrain[x] = int(f32(level.terrain[x])*(1-t)+f32(surface)*t+0.5)
    }
    return surface
}

place_house :: proc(w: ^World, house: ^House) {
    // A wood facade with a door and two windows, capped by a filled triangle.
    door_left := house.x+house.width/2-8
    for dy := 0; dy < house.height; dy += 1 {
        for dx := 0; dx < house.width; dx += 1 {
            x := house.x+dx
            if dy >= house.height-22 && x >= door_left && x < door_left+16 { continue }
            window_y := dy >= 9 && dy < 17
            left_window := dx >= house.width/4-4 && dx < house.width/4+4
            right_window := dx >= house.width*3/4-4 && dx < house.width*3/4+4
            if window_y && (left_window || right_window) { continue }
            place(w, x, house.y+dy, .Wood)
        }
    }
    half := house.width/2
    for row := 0; row < house.roof_height; row += 1 {
        spread := (row+1)*half/house.roof_height
        for dx := -spread; dx <= spread; dx += 1 {
            place(w, house.x+half+dx, house.y-house.roof_height+row, .Wood)
        }
    }
}

choose_vessel_material :: proc(seed: ^u32) -> Material {
    contents := [7]Material{.Water, .Petrol, .Acid, .Lava, .Sand, .Powder, .Snow}
    return contents[level_random(seed)%u32(len(contents))]
}

place_vessel :: proc(w: ^World, vessel: ^Vessel) {
    // Two-cell glass walls keep the powder or liquid contained until broken.
    for dy := 0; dy < vessel.height; dy += 1 {
        for dx := 0; dx < vessel.width; dx += 1 {
            wall := dx < 2 || dx >= vessel.width-2 || dy >= vessel.height-2
            lip := dy < 2 && (dx < 5 || dx >= vessel.width-5)
            if wall || lip { place(w, vessel.x+dx, vessel.y+dy, .Glass) }
        }
    }
    fill_top := vessel.height/3
    for dy := fill_top; dy < vessel.height-2; dy += 1 {
        for dx := 2; dx < vessel.width-2; dx += 1 {
            place(w, vessel.x+dx, vessel.y+dy, vessel.material)
        }
    }
}

generate_level :: proc(w: ^World, level: ^Level, random_seed: u32) {
    seed := random_seed
    generate_terrain(level, &seed)
    // Keep the final arena open for the FreeKnight encounter.
    flatten_terrain(level, WORLD_W-300, WORLD_W)

    // The first section is a scripted cave. Procedural scenery begins outside it.
    prepare_intro_terrain(level)
    level.barrels[level.barrel_count] = Barrel{x = INTRO_BARREL_X, y = level.terrain[INTRO_BARREL_X]-BARREL_H, material = .Plasma}
    level.barrel_count += 1
    x := CAVE_EXIT_X+95+int(level_random(&seed)%35)
    for x < WORLD_W-430 {
        prop_roll := level_random(&seed)%100
        width := BARREL_W
        if prop_roll < 30 && level.house_count < MAX_LEVEL_HOUSES {
            width = 54+int(level_random(&seed)%37)
            height := 27+int(level_random(&seed)%12)
            roof_height := 13+int(level_random(&seed)%8)
            surface := flatten_terrain(level, x, x+width)
            level.houses[level.house_count] = House{x, surface-height, width, height, roof_height}
            level.house_count += 1
        } else if prop_roll < 55 && level.vessel_count < MAX_LEVEL_VESSELS {
            width = 30+int(level_random(&seed)%15)
            height := 24+int(level_random(&seed)%10)
            surface := flatten_terrain(level, x, x+width)
            level.vessels[level.vessel_count] = Vessel{x, surface-height, width, height, choose_vessel_material(&seed)}
            level.vessel_count += 1
        } else if level.barrel_count < MAX_LEVEL_BARRELS {
            surface := flatten_terrain(level, x, x+BARREL_W)
            material := choose_barrel_material(&seed)
            level.barrels[level.barrel_count] = Barrel{x = x, y = surface-BARREL_H, material = material}
            level.barrel_count += 1
        }
        x += width+78+int(level_random(&seed)%70)
    }

    for x := 0; x < WORLD_W; x += 1 {
        for y := level.terrain[x]; y < WORLD_H; y += 1 {
            material := Material.Stone
            depth := y-level.terrain[x]
            if x > CAVE_EXIT_X && depth < GRASS_DEPTH { material = .Grass }
            else if x > CAVE_EXIT_X && depth < SOIL_DEPTH { material = .Ground }
            place(w, x, y, material)
        }
    }
    place_intro_cave(w, level)
    for i := 0; i < level.house_count; i += 1 { place_house(w, &level.houses[i]) }
    for i := 0; i < level.barrel_count; i += 1 { place_barrel(w, &level.barrels[i]) }
    for i := 0; i < level.vessel_count; i += 1 { place_vessel(w, &level.vessels[i]) }
    spawn_level_enemies(w, level, &seed)
}

consuming_barrel :: proc(level: ^Level) -> ^Barrel {
    for i := 0; i < level.barrel_count; i += 1 {
        if level.barrels[i].consuming { return &level.barrels[i] }
    }
    return nil
}

any_barrel_consuming :: proc(level: ^Level) -> bool {
    return consuming_barrel(level) != nil
}

begin_eat_nearby_barrel :: proc(level: ^Level, player: ^Player, inventory: ^Inventory) -> bool {
    if any_barrel_consuming(level) { return false }
    nearest := -1
    nearest_distance := 1000000
    for i := 0; i < level.barrel_count; i += 1 {
        barrel := &level.barrels[i]
        if barrel.broken || !barrel_in_reach(barrel, player) || !inventory_can_add(inventory, barrel.material) { continue }
        distance := abs(player.x+PLAYER_W/2-barrel.x-BARREL_W/2)
        if distance < nearest_distance { nearest, nearest_distance = i, distance }
    }
    if nearest < 0 { return false }
    return begin_eat_barrel(&level.barrels[nearest], player, inventory)
}
