package main

import "core:testing"
import "core:c"
import rl "vendor:raylib"

@test
embedded_assets_decode_without_runtime_files :: proc(t: ^testing.T) {
    image_data := embedded_asset("assets/sprites/intro_egg.png")
    wave_data := embedded_asset("assets/sfx/jump_01.wav")
    shader_data := embedded_asset("assets/shaders/intro_slowmo.fs")
    testing.expect(t, len(image_data) > 8 && image_data[1] == 'P' && image_data[2] == 'N')
    testing.expect(t, len(wave_data) > 12 && wave_data[0] == 'R' && wave_data[1] == 'I')
    testing.expect(t, len(shader_data) > 10 && shader_data[0] == '#')

    image := load_embedded_image("assets/sprites/intro_egg.png")
    testing.expect(t, rl.IsImageValid(image))
    if rl.IsImageValid(image) { rl.UnloadImage(image) }

    wave := rl.LoadWaveFromMemory(".wav", raw_data(wave_data), c.int(len(wave_data)))
    testing.expect(t, rl.IsWaveValid(wave))
    if rl.IsWaveValid(wave) { rl.UnloadWave(wave) }
}
