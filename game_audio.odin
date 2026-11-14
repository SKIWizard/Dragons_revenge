package main

import rl "vendor:raylib"

SFX_VARIANTS :: 3
GAME_MASTER_VOLUME :: f32(0.75)

SfxCue :: enum {
    FootStone, FootWood, FootGrass, FootMetal, FootSnow, FootWater,
    Jump, Land, Turn, DragonBlip, KnightBlip, HurtPlayer, HurtEnemy,
    Slash, Charge, Projectile, FireBreath, Plasma, Acid,
    Egg, Barrel, Explosion, Pickup, UiSelect, UiMove, UiBack,
    Count,
}

SFX_NAMES := [int(SfxCue.Count)]cstring{
    "footstep_stone", "footstep_wood", "footstep_grass", "footstep_metal",
    "footstep_snow", "footstep_water", "jump", "land_soft", "dash",
    "dialogue_dragon", "dialogue_knight", "hurt_player", "hurt_enemy",
    "attack_slash", "enemy_charge", "attack_projectile", "fire_breath",
    "plasma_beam", "acid_sizzle", "egg_crack", "barrel_break", "explosion",
    "pickup", "ui_select", "ui_move", "ui_back",
}

GameAudio :: struct {
    sounds: [int(SfxCue.Count)][SFX_VARIANTS]rl.Sound,
    ready: bool,
    random_state: u32,
    footstep_timer, spray_timer, dialogue_timer, hurt_enemy_timer: f32,
}

init_game_audio :: proc() -> GameAudio {
    result := GameAudio{random_state = 0x5F11D042}
    rl.InitAudioDevice()
    if !rl.IsAudioDeviceReady() { return result }
    result.ready = true
    rl.SetMasterVolume(GAME_MASTER_VOLUME)
    for name, cue in SFX_NAMES {
        for variant in 0..<SFX_VARIANTS {
            path := rl.TextFormat("assets/sfx/%s_%02d.wav", name, variant+1)
            result.sounds[cue][variant] = rl.LoadSound(path)
        }
    }
    return result
}

unload_game_audio :: proc(audio: ^GameAudio) {
    if !audio.ready { return }
    for variants in audio.sounds {
        for sound in variants {
            if rl.IsSoundValid(sound) { rl.UnloadSound(sound) }
        }
    }
    rl.CloseAudioDevice()
    audio.ready = false
}

play_game_sound :: proc(audio: ^GameAudio, cue: SfxCue, volume: f32) {
    if !audio.ready { return }
    audio.random_state = audio.random_state*1664525+1013904223
    variant := int((audio.random_state>>16)%SFX_VARIANTS)
    sound := audio.sounds[cue][variant]
    if !rl.IsSoundValid(sound) { return }
    rl.SetSoundVolume(sound, volume)
    rl.PlaySound(sound)
}

tick_game_audio :: proc(audio: ^GameAudio, dt: f32) {
    audio.footstep_timer = max(0, audio.footstep_timer-dt)
    audio.spray_timer = max(0, audio.spray_timer-dt)
    audio.dialogue_timer = max(0, audio.dialogue_timer-dt)
    audio.hurt_enemy_timer = max(0, audio.hurt_enemy_timer-dt)
}

footstep_cue :: proc(material: Material) -> SfxCue {
    #partial switch material {
    case .Wood: return .FootWood
    case .Grass, .Ground: return .FootGrass
    case .Iron: return .FootMetal
    case .Snow: return .FootSnow
    case .Water: return .FootWater
    }
    return .FootStone
}

play_movement_sfx :: proc(audio: ^GameAudio, w: ^World, player: ^Player,
                          old_x: int, old_vy: f32, was_grounded: bool) {
    if old_vy >= 0 && player.vy < 0 {
        play_game_sound(audio, .Jump, 0.35)
        audio.footstep_timer = 0.12
    } else if !was_grounded && player.grounded {
        play_game_sound(audio, .Land, 0.40)
        audio.footstep_timer = 0.12
    }
    if player.grounded && player.x != old_x && audio.footstep_timer <= 0 {
        play_game_sound(audio, footstep_cue(movement_surface(w, player)), 0.23)
        audio.footstep_timer = 0.14
    }
}

play_spray_sfx :: proc(audio: ^GameAudio, material: Material, emitted: int) {
    if emitted <= 0 || audio.spray_timer > 0 { return }
    cue := SfxCue.Projectile
    #partial switch material {
    case .Fire: cue = .FireBreath
    case .Plasma: cue = .Plasma
    case .Acid: cue = .Acid
    }
    play_game_sound(audio, cue, 0.32)
    audio.spray_timer = 0.28
}

play_dialogue_sfx :: proc(audio: ^GameAudio, card: DialogueCard, before, after: int) {
    if after/3 <= before/3 || audio.dialogue_timer > 0 { return }
    cue := SfxCue.DragonBlip
    if card == .Knight || card == .KnightThreat { cue = .KnightBlip }
    play_game_sound(audio, cue, 0.22)
    audio.dialogue_timer = 0.055
}

play_enemy_hurt_sfx :: proc(audio: ^GameAudio) {
    if audio.hurt_enemy_timer > 0 { return }
    play_game_sound(audio, .HurtEnemy, 0.28)
    audio.hurt_enemy_timer = 0.14
}
