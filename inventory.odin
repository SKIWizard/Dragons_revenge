package main

import rl "vendor:raylib"
import "core:c"

INVENTORY_SIZE :: 5
PLAYER_MAX_HEALTH :: 100
SLOT_SPACING :: 60
SLOT_SIZE :: 54

InventorySlot :: struct {
    material: Material,
    count: int,
}

Inventory :: struct {
    slots: [INVENTORY_SIZE]InventorySlot,
    selected: int,
}

starting_inventory :: proc() -> Inventory {
    inventory := Inventory{}
    inventory.slots[0] = InventorySlot{material = .Fire, count = -1}
    return inventory
}

inventory_can_add :: proc(inventory: ^Inventory, material: Material) -> bool {
    for slot in inventory.slots {
        if slot.count != 0 && slot.material == material { return true }
        if slot.count == 0 { return true }
    }
    return false
}

inventory_add :: proc(inventory: ^Inventory, material: Material, amount: int) -> bool {
    if amount <= 0 || material == .Empty { return false }
    for &slot in inventory.slots {
        if slot.count != 0 && slot.material == material {
            if slot.count > 0 { slot.count += amount }
            return true
        }
    }
    for &slot in inventory.slots {
        if slot.count == 0 {
            slot.material = material
            slot.count = amount
            return true
        }
    }
    return false
}

// Reserved for the future spit ability: one stored unit equals one cell.
inventory_take :: proc(inventory: ^Inventory, slot_index, amount: int) -> int {
    if slot_index < 0 || slot_index >= INVENTORY_SIZE || amount <= 0 { return 0 }
    slot := &inventory.slots[slot_index]
    if slot.count < 0 { return amount }
    taken := min(slot.count, amount)
    slot.count -= taken
    if slot.count == 0 { slot.material = .Empty }
    return taken
}

inventory_select :: proc(inventory: ^Inventory, slot: int) {
    if slot >= 0 && slot < INVENTORY_SIZE { inventory.selected = slot }
}

inventory_scroll :: proc(inventory: ^Inventory, steps: int) {
    inventory.selected = ((inventory.selected-steps)%INVENTORY_SIZE+INVENTORY_SIZE)%INVENTORY_SIZE
}

draw_material_icon :: proc(sheet: rl.Texture2D, material: Material, x, y, scale: int) {
    if material == .Empty || !rl.IsTextureValid(sheet) { return }
    source := rl.Rectangle{f32((int(material)-1)*16), 0, 16, 16}
    destination := rl.Rectangle{f32(x), f32(y), f32(16*scale), f32(16*scale)}
    rl.DrawTexturePro(sheet, source, destination, rl.Vector2{}, 0, rl.WHITE)
}

draw_material_cursor :: proc(inventory: ^Inventory, sheet: rl.Texture2D, mouse_x, mouse_y: int) {
    slot := inventory.slots[inventory.selected]
    if slot.count != 0 {
        draw_material_icon(sheet, slot.material, mouse_x-8, mouse_y-8, 1)
    } else {
        rl.DrawLine(c.int(mouse_x-5), c.int(mouse_y), c.int(mouse_x+5), c.int(mouse_y), rl.WHITE)
        rl.DrawLine(c.int(mouse_x), c.int(mouse_y-5), c.int(mouse_x), c.int(mouse_y+5), rl.WHITE)
    }
}

handle_inventory_input :: proc(inventory: ^Inventory) {
    keys := [INVENTORY_SIZE]rl.KeyboardKey{.ONE, .TWO, .THREE, .FOUR, .FIVE}
    for key, i in keys {
        if rl.IsKeyPressed(key) { inventory_select(inventory, i) }
    }
    wheel := rl.GetMouseWheelMove()
    if wheel > 0 { inventory_scroll(inventory, max(1, int(wheel))) }
    if wheel < 0 { inventory_scroll(inventory, min(-1, int(wheel))) }
}

draw_player_hud :: proc(health: int, inventory: ^Inventory, icon_sheet: rl.Texture2D, show_inventory: bool) {
    screen_width := VIEW_W*CELL_SIZE
    health_x := screen_width-206
    rl.DrawRectangle(c.int(health_x), 12, 194, 30, rl.Color{19, 25, 31, 225})
    rl.DrawRectangle(c.int(health_x+7), 19, 180, 16, rl.Color{72, 35, 37, 255})
    fill := 180*max(0, min(health, PLAYER_MAX_HEALTH))/PLAYER_MAX_HEALTH
    rl.DrawRectangle(c.int(health_x+7), 19, c.int(fill), 16, rl.Color{225, 68, 76, 255})
    rl.DrawText("HP", c.int(health_x+10), 20, 12, rl.WHITE)

    if !show_inventory { return }

    start_x := 12
    y := 12
    for slot, i in inventory.slots {
        x := start_x+i*SLOT_SPACING
        border := rl.Color{90, 107, 109, 255}
        if i == inventory.selected { border = rl.Color{255, 215, 106, 255} }
        rl.DrawRectangle(c.int(x), c.int(y), SLOT_SIZE, SLOT_SIZE, border)
        rl.DrawRectangle(c.int(x+3), c.int(y+3), SLOT_SIZE-6, SLOT_SIZE-6, rl.Color{27, 36, 42, 230})
        rl.DrawText(rl.TextFormat("%d", i+1), c.int(x+5), c.int(y+4), 12, rl.Color{205, 213, 210, 255})
        if slot.count == 0 { continue }
        draw_material_icon(icon_sheet, slot.material, x+11, y+7, 2)
        if slot.count < 0 {
            rl.DrawText("INF", c.int(x+6), c.int(y+37), 13, rl.WHITE)
        } else {
            rl.DrawText(rl.TextFormat("%d", slot.count), c.int(x+6), c.int(y+37), 13, rl.WHITE)
        }
    }
}
