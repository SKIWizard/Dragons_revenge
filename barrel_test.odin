package main

import "core:testing"

@test
barrel_breaks_after_first_lost_wood_cell :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    barrel := Barrel{x = 80, y = 80, material = .Snow}
    player := Player{x = 200, y = 200}
    inventory := Inventory{}
    place_barrel(w, &barrel)

    wood_before := count_kind(w, .Wood)
    testing.expect(t, wood_before > 300)
    testing.expect(t, !barrel_damaged(w, &barrel))

    place(w, 80+BARREL_W/2, 80+BARREL_H/2, .Empty)
    update_barrel(w, &barrel, &player, &inventory)

    testing.expect(t, barrel.broken)
    testing.expect(t, count_kind(w, .Wood) == 0)
    testing.expect(t, count_kind(w, .Snow) > 250)

    for _ in 0..<40 { update_barrel(w, &barrel, &player, &inventory) }
    testing.expect(t, barrel.finished)
}

@test
eating_barrel_stores_snow_without_spilling_it :: proc(t: ^testing.T) {
    w := new(World)
    defer free(w)
    barrel := Barrel{x = 100, y = 80, material = .Snow}
    place_barrel(w, &barrel)
    player := Player{x = 86, y = 84}
    inventory := Inventory{}
    testing.expect(t, begin_eat_barrel(&barrel, &player, &inventory))
    testing.expect(t, barrel.consuming)
    for _ in 0..<30 { update_barrel(w, &barrel, &player, &inventory) }
    testing.expect(t, barrel.broken && barrel.consumed)
    testing.expect(t, count_kind(w, .Wood) == 0)
    testing.expect(t, count_kind(w, .Snow) == 0)
    testing.expect(t, inventory.slots[0].material == .Snow)
    testing.expect(t, inventory.slots[0].count == BARREL_CONTENT_AMOUNT)
    for _ in 0..<30 { update_barrel(w, &barrel, &player, &inventory) }
    testing.expect(t, barrel.finished && !barrel.consuming)
    testing.expect(t, !begin_eat_barrel(&barrel, &player, &inventory))
}
