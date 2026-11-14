package main

import rl "vendor:raylib"
import "core:c"

DialogueCard :: enum {None, Awakening, Knight, DragonShock, KnightThreat, DragonVow,
                      BossQuestion, BossAnswer, BossDefiance, BossFarewell}

DialogueState :: struct {
    card: DialogueCard,
    visible: f32,
}

DIALOGUE_CHAR_WIDTH :: 16
DIALOGUE_ROW_HEIGHT :: 30
DIALOGUE_SPEED :: f32(31)

dialogue_lengths :: proc(card: DialogueCard) -> [3]int {
    switch card {
    case .Awakening: return [3]int{23, 0, 0}
    case .Knight: return [3]int{33, 20, 0}
    case .DragonShock: return [3]int{25, 0, 0}
    case .KnightThreat: return [3]int{37, 30, 0}
    case .DragonVow: return [3]int{35, 21, 0}
    case .BossQuestion: return [3]int{26, 0, 0}
    case .BossAnswer: return [3]int{34, 0, 0}
    case .BossDefiance: return [3]int{30, 0, 0}
    case .BossFarewell: return [3]int{23, 0, 0}
    case .None: return [3]int{}
    }
    return [3]int{}
}

dialogue_total :: proc(card: DialogueCard) -> int {
    total := 0
    for count in dialogue_lengths(card) { total += count }
    return total
}

begin_dialogue :: proc(state: ^DialogueState, card: DialogueCard) {
    state.card = card
    state.visible = 0
}

update_dialogue :: proc(state: ^DialogueState, dt: f32, advance: bool) -> bool {
    if state.card == .None { return false }
    total := dialogue_total(state.card)
    if state.visible >= f32(total) && advance {
        state.card = .None
        state.visible = 0
        return true
    }
    state.visible = min(f32(total), state.visible+dt*DIALOGUE_SPEED)
    return false
}

draw_dialogue :: proc(state: ^DialogueState, text_sheet, portrait: rl.Texture2D) {
    if state.card == .None { return }
    panel_x, panel_y := 45, 410
    rl.DrawRectangle(0, 0, CANVAS_W, CANVAS_H, rl.Color{8, 10, 20, 95})
    rl.DrawRectangle(c.int(panel_x), c.int(panel_y), 990, 169, rl.Color{207, 175, 116, 255})
    rl.DrawRectangle(c.int(panel_x+4), c.int(panel_y+4), 982, 161, rl.Color{24, 28, 42, 244})
    rl.DrawRectangle(c.int(panel_x+16), c.int(panel_y+16), 134, 134, rl.Color{9, 12, 23, 255})
    if rl.IsTextureValid(portrait) {
        rl.DrawTexturePro(portrait,
            rl.Rectangle{0, 0, f32(portrait.width), f32(portrait.height)},
            rl.Rectangle{f32(panel_x+19), f32(panel_y+19), 128, 128},
            rl.Vector2{}, 0, rl.WHITE)
    }
    if rl.IsTextureValid(text_sheet) {
        remaining := int(state.visible)
        for length, row in dialogue_lengths(state.card) {
            shown := min(length, max(0, remaining))
            if shown > 0 {
                width := f32(shown*DIALOGUE_CHAR_WIDTH)
                rl.DrawTexturePro(text_sheet,
                    rl.Rectangle{0, f32(row*DIALOGUE_ROW_HEIGHT), width, DIALOGUE_ROW_HEIGHT},
                    rl.Rectangle{f32(panel_x+169), f32(panel_y+31+row*DIALOGUE_ROW_HEIGHT), width, DIALOGUE_ROW_HEIGHT},
                    rl.Vector2{}, 0, rl.WHITE)
            }
            remaining -= length
        }
    }
    if state.visible >= f32(dialogue_total(state.card)) {
        x, y := panel_x+960, panel_y+136
        rl.DrawTriangle(rl.Vector2{f32(x), f32(y)}, rl.Vector2{f32(x+13), f32(y)},
            rl.Vector2{f32(x+6), f32(y+10)}, rl.Color{255, 213, 127, 255})
    }
}
