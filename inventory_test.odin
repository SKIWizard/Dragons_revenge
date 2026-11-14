package main

import "core:testing"

@test
inventory_stacks_materials_and_selects_five_slots :: proc(t: ^testing.T) {
    inventory := Inventory{}
    testing.expect(t, inventory.selected == 0)
    testing.expect(t, inventory_add(&inventory, .Snow, 100))
    testing.expect(t, inventory_add(&inventory, .Snow, 25))
    testing.expect(t, inventory.slots[0].material == .Snow)
    testing.expect(t, inventory.slots[0].count == 125)
    testing.expect(t, inventory_add(&inventory, .Water, 30))
    testing.expect(t, inventory.slots[1].material == .Water)
    testing.expect(t, inventory_take(&inventory, 0, 125) == 125)
    testing.expect(t, inventory.slots[0].count == 0)
    testing.expect(t, inventory.slots[0].material == .Empty)
    inventory_select(&inventory, 4)
    testing.expect(t, inventory.selected == 4)
    inventory_scroll(&inventory, -1)
    testing.expect(t, inventory.selected == 0)
    inventory_scroll(&inventory, 1)
    testing.expect(t, inventory.selected == 4)
}

@test
full_inventory_prevents_eating_new_material :: proc(t: ^testing.T) {
    inventory := Inventory{}
    materials := [5]Material{.Water, .Sand, .Wood, .Stone, .Fire}
    for material in materials {
        testing.expect(t, inventory_add(&inventory, material, 1))
    }
    testing.expect(t, !inventory_can_add(&inventory, .Snow))
    testing.expect(t, !inventory_add(&inventory, .Snow, 100))
}

@test
first_slot_starts_with_infinite_fire :: proc(t: ^testing.T) {
    inventory := starting_inventory()
    testing.expect(t, inventory.selected == 0)
    testing.expect(t, inventory.slots[0].material == .Fire)
    testing.expect(t, inventory.slots[0].count == -1)
    testing.expect(t, inventory_take(&inventory, 0, 500) == 500)
    testing.expect(t, inventory.slots[0].count == -1)
    testing.expect(t, inventory_add(&inventory, .Snow, 100))
    testing.expect(t, inventory.slots[1].material == .Snow)
    testing.expect(t, inventory.slots[1].count == 100)
}
