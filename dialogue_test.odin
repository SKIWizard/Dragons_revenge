package main

import "core:testing"

@test
dialogue_reveals_text_before_advance :: proc(t: ^testing.T) {
    state := DialogueState{}
    begin_dialogue(&state, .Knight)
    testing.expect(t, dialogue_total(state.card) == 53)
    testing.expect(t, !update_dialogue(&state, 0.1, true))
    testing.expect(t, state.card == .Knight)
    testing.expect(t, state.visible > 0 && state.visible < 53)
    testing.expect(t, !update_dialogue(&state, 1, false))
    testing.expect(t, state.visible < 35)
    testing.expect(t, !update_dialogue(&state, 1, false))
    testing.expect(t, state.visible == 53)
    testing.expect(t, update_dialogue(&state, 0, true))
    testing.expect(t, state.card == .None)
}

@test
intro_dialogue_cards_have_all_four_encounter_lines :: proc(t: ^testing.T) {
    testing.expect(t, dialogue_total(.Knight) == 53)
    testing.expect(t, dialogue_total(.DragonShock) == 25)
    testing.expect(t, dialogue_total(.KnightThreat) == 67)
    testing.expect(t, dialogue_total(.DragonVow) == 56)
}
