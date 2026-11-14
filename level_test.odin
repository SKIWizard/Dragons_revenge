package main

import "core:testing"

@test
barrel_material_weights_prioritize_fuel_and_rare_solids :: proc(t: ^testing.T) {
    counts: [Material]int
    seed: u32 = 12345
    for _ in 0..<10000 { counts[choose_barrel_material(&seed)] += 1 }
    testing.expect(t, counts[.Powder] > counts[.Acid])
    testing.expect(t, counts[.Petrol] > counts[.Plasma])
    testing.expect(t, counts[.Acid] > counts[.Water])
    testing.expect(t, counts[.Plasma] > counts[.Snow])
    testing.expect(t, counts[.Water] > counts[.Sand])
    testing.expect(t, counts[.Snow] > counts[.Steam])
    testing.expect(t, counts[.Sand] > counts[.Stone])
    testing.expect(t, counts[.Smoke] > counts[.Iron])
}

@test
vessels_choose_only_powders_or_liquids :: proc(t: ^testing.T) {
    seed: u32 = 54321
    powders, liquids := 0, 0
    for _ in 0..<1000 {
        material := choose_vessel_material(&seed)
        testing.expect(t, powder(material) || liquid(material))
        if powder(material) { powders += 1 }
        if liquid(material) { liquids += 1 }
    }
    testing.expect(t, powders > 0 && liquids > 0)
}

@test
generated_level_has_continuous_walkable_terrain_and_props :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    level := new(Level)
    defer free(level)
    w.random_state = 1
    generate_level(w, level, 12345)

    testing.expect(t, WORLD_W >= VIEW_W*6)
    testing.expect(t, level.barrel_count > 0)
    testing.expect(t, level.house_count > 0)
    testing.expect(t, level.vessel_count > 0)
    testing.expect(t, w.enemy_count > 0)
    testing.expect(t, level.terrain[53] == FLOOR_Y)
    for x := 0; x < WORLD_W; x += 1 {
        y := level.terrain[x]
        testing.expect(t, y > 0 && y < WORLD_H)
        if x <= CAVE_EXIT_X {
            testing.expect(t, kind_at(w, x, y) == .Stone)
            testing.expect(t, kind_at(w, x, intro_roof(x)) == .Stone)
        } else {
            testing.expect(t, kind_at(w, x, y) == .Grass)
            testing.expect(t, kind_at(w, x, y+GRASS_DEPTH-1) == .Grass)
            testing.expect(t, kind_at(w, x, y+GRASS_DEPTH) == .Ground)
            testing.expect(t, kind_at(w, x, y+SOIL_DEPTH-1) == .Ground)
            testing.expect(t, kind_at(w, x, y+SOIL_DEPTH) == .Stone)
        }
        if x > 0 { testing.expect(t, abs(y-level.terrain[x-1]) <= MAX_STEP_HEIGHT) }
    }
    for i := 0; i < level.barrel_count; i += 1 {
        barrel := &level.barrels[i]
        testing.expect(t, barrel.material != .Empty && barrel.material != .Fire)
        testing.expect(t, barrel.y+BARREL_H == level.terrain[barrel.x])
        testing.expect(t, !barrel_damaged(w, barrel))
    }
    for i := 0; i < level.house_count; i += 1 {
        house := &level.houses[i]
        testing.expect(t, house.width >= 54 && house.width <= 90)
        testing.expect(t, house.y+house.height == level.terrain[house.x])
        testing.expect(t, kind_at(w, house.x+house.width/2, house.y-house.roof_height+2) == .Wood)
    }
    for i := 0; i < level.vessel_count; i += 1 {
        vessel := &level.vessels[i]
        testing.expect(t, vessel.y+vessel.height == level.terrain[vessel.x])
        testing.expect(t, kind_at(w, vessel.x, vessel.y+vessel.height/2) == .Glass)
        testing.expect(t, liquid(vessel.material) || powder(vessel.material))
        testing.expect(t, kind_at(w, vessel.x+vessel.width/2, vessel.y+vessel.height/2) == vessel.material)
    }
    for i := 0; i < w.enemy_count; i += 1 {
        enemy := &w.enemies[i]
        testing.expect(t, enemy.alive)
        testing.expect(t, !enemy_hits_kind(w, enemy.kind, enemy.x, enemy.y))
        testing.expect(t, enemy_hits_kind(w, enemy.kind, enemy.x, enemy.y+1))
    }
    ogres, barbarians, bosses := 0, 0, 0
    for i := 0; i < w.enemy_count; i += 1 {
        if w.enemies[i].kind == .Ogre { ogres += 1 }
        if w.enemies[i].kind == .Barbarian { barbarians += 1 }
        if w.enemies[i].kind == .Boss {
            bosses += 1
            testing.expect(t, w.enemies[i].x >= WORLD_W-300)
            testing.expect(t, w.enemies[i].health == BOSS_HEALTH)
        }
    }
    testing.expect(t, ogres > 0)
    testing.expect(t, barbarians > 0)
    testing.expect(t, bosses == 1)
    testing.expect(t, w.enemy_count > 16)
    squad_sizes: [20]int
    for i := 0; i < w.enemy_count; i += 1 {
        enemy := &w.enemies[i]
        if enemy.kind == .Knight { squad_sizes[enemy.squad_id] += 1 }
    }
    groups := 0
    for size in squad_sizes {
        if size > 0 {
            groups += 1
            testing.expect(t, size >= 2 && size <= 5)
        }
    }
    testing.expect(t, groups >= 5)
}

@test
generated_houses_and_barrels_remain_static :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    level := new(Level)
    defer free(level)
    generate_level(w, level, 12345)
    for _ in 0..<6 { step_world(w) }
    for i := 0; i < level.barrel_count; i += 1 {
        testing.expect(t, !barrel_damaged(w, &level.barrels[i]))
    }
    for i := 0; i < level.house_count; i += 1 {
        house := &level.houses[i]
        testing.expect(t, kind_at(w, house.x+house.width/2, house.y-house.roof_height+2) == .Wood)
    }
}

@test
glass_vessel_contains_liquid_until_wall_breaks :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    w.random_state = 7
    vessel := Vessel{100, 110, 36, 30, .Water}
    for x := 80; x < 155; x += 1 { place(w, x, 140, .Stone) }
    place_vessel(w, &vessel)
    for _ in 0..<20 { step_world(w) }
    testing.expect(t, kind_at(w, 101, 128) == .Glass)
    testing.expect(t, kind_at(w, 110, 128) == .Water)
    testing.expect(t, kind_at(w, 98, 128) == .Empty)
    for y := 128; y < 138; y += 1 {
        place(w, 100, y, .Empty)
        place(w, 101, y, .Empty)
    }
    for _ in 0..<90 { step_world(w) }
    leaked := false
    for y := 120; y < 160; y += 1 {
        for x := 94; x < 100; x += 1 {
            if kind_at(w, x, y) == .Water { leaked = true }
        }
    }
    testing.expect(t, leaked)
}

@test
barrel_contents_are_used_for_eating :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    barrel := Barrel{x = 100, y = 80, material = .Acid}
    place_barrel(w, &barrel)
    player := Player{x = 86, y = 84}
    inventory := starting_inventory()
    testing.expect(t, begin_eat_barrel(&barrel, &player, &inventory))
    for _ in 0..<30 { update_barrel(w, &barrel, &player, &inventory) }
    testing.expect(t, inventory.slots[1].material == .Acid)
    testing.expect(t, inventory.slots[1].count == BARREL_CONTENT_AMOUNT)
}

@test
barrel_releases_its_own_material_when_damaged :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    barrel := Barrel{x = 100, y = 80, material = .Water}
    place_barrel(w, &barrel)
    player := Player{x = 200, y = 80}
    inventory := Inventory{}
    place(w, barrel.x+BARREL_W/2, barrel.y+BARREL_H/2, .Empty)
    update_barrel(w, &barrel, &player, &inventory)
    testing.expect(t, barrel.broken)
    testing.expect(t, count_kind(w, .Water) > 0)
    testing.expect(t, count_kind(w, .Snow) == 0)
}
