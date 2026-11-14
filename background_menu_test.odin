package main

import "core:testing"

@test
secret_menu_requires_full_sequence :: proc(t: ^testing.T) {
    menu := SandboxMenu{selected = .Fire}
    feed_secret_key(&menu, .I)
    feed_secret_key(&menu, .D)
    feed_secret_key(&menu, .Q)
    testing.expect(t, !menu.unlocked && !menu.open)
    feed_secret_key(&menu, .I)
    feed_secret_key(&menu, .D)
    feed_secret_key(&menu, .D)
    feed_secret_key(&menu, .Q)
    feed_secret_key(&menu, .D)
    testing.expect(t, menu.unlocked && menu.open)
}

@test
background_scroll_is_continuous_and_bounded :: proc(t: ^testing.T) {
    left := background_source_x(2168, 725, 0)
    middle := background_source_x(2168, 725, f32(WORLD_W-VIEW_W)*0.5)
    right := background_source_x(2168, 725, f32(WORLD_W-VIEW_W))
    testing.expect(t, left == 0)
    testing.expect(t, middle > left && middle < right)
    testing.expect(t, background_source_x(2168, 725, -100) == left)
    testing.expect(t, background_source_x(2168, 725, 9999) == right)
}
