package main

import "core:testing"

@test
menu_starts_game_and_settings_adjust_volume :: proc(t: ^testing.T) {
    screen := GameScreen.Title
    volume: f32 = 0.75
    testing.expect(t, !update_game_menu(&screen, &volume, MENU_BUTTON_X+20, MENU_SETTINGS_Y+20,
        true, false, false, false, false, false, false))
    testing.expect(t, screen == .Settings)
    update_game_menu(&screen, &volume, MENU_SLIDER_X+MENU_SLIDER_W/2, MENU_SLIDER_Y,
        false, true, false, false, false, false, false)
    testing.expect(t, volume > 0.49 && volume < 0.51)
    update_game_menu(&screen, &volume, 0, 0, false, false, false, false, true, false, false)
    testing.expect(t, screen == .Title)
    testing.expect(t, update_game_menu(&screen, &volume, 0, 0, false, false, true, false, false, false, false))
    testing.expect(t, screen == .Playing)
}
