package main

import rl "vendor:raylib"

WORLD_W :: 3400
WORLD_H :: 300
VIEW_W :: 360
VIEW_H :: 203
CELL_SIZE :: 3

Material :: enum u8 {
    Empty,
    Sand,
    Water,
    Stone,
    Smoke,
    Wood,
    Fire,
    Steam,
    Plasma,
    Lava,
    Powder,
    Boom,
    Petrol,
    Acid,
    Iron,
    Snow,
    KnightDebris,
    OgreDebris,
    Ground,
    Grass,
    Glass,
    Blood,
    Potion,
}

Cell :: struct {
    kind: Material,
    shade: u8,
    temperature: i32,
    health: i16,
    life: i16,
    max_life: i16,
    burn_progress: i16,
    rest_ticks: u8,
    burning: bool,
    vx, vy, travel: f32,
    scatter_x, scatter_y: f32,
    scatter_ticks: u8,
    origin: Material,
    updated: u32,
}

MAX_BLAST_SPARKS :: 2048
BLAST_TILE :: 8
BLAST_COLS :: (WORLD_W+BLAST_TILE-1)/BLAST_TILE
BLAST_ROWS :: (WORLD_H+BLAST_TILE-1)/BLAST_TILE

Blast_Spark :: struct {
    x, y, vx, vy: f32,
    life, max_life: u8,
    shade: u8,
}

World :: struct {
    cells: [WORLD_W * WORLD_H]Cell,
    player_collision_active: bool,
    player_x, player_y: int,
    enemies: [MAX_ENEMIES]Enemy,
    enemy_count: int,
    boss_locked: bool,
    tick: u32,
    random_state: u32,
    active_a, active_b: [WORLD_W * WORLD_H]i32,
    queued_for: [WORLD_W * WORLD_H]u32,
    active_count, next_count: int,
    current_b, stepping: bool,
    blast_ticks: [BLAST_COLS*BLAST_ROWS]u32,
    blast_sparks: [MAX_BLAST_SPARKS]Blast_Spark,
    blast_spark_count: int,
    blast_events: u32,
}

palette := [Material][4]rl.Color {
    .Empty = {{13, 17, 25, 255}, {13, 17, 25, 255}, {13, 17, 25, 255}, {13, 17, 25, 255}},
    .Sand = {{255, 255, 0, 255}, {255, 230, 0, 255}, {240, 220, 70, 255}, {210, 180, 40, 255}},
    .Water = {{0, 0, 255, 255}, {30, 144, 255, 255}, {0, 105, 148, 255}, {70, 130, 180, 255}},
    .Stone = {{80, 80, 80, 255}, {105, 105, 105, 255}, {169, 169, 169, 255}, {120, 120, 120, 255}},
    .Smoke = {{128, 128, 128, 255}, {140, 140, 140, 255}, {160, 160, 160, 255}, {180, 180, 180, 255}},
    .Wood = {{150, 111, 51, 255}, {139, 69, 19, 255}, {160, 120, 80, 255}, {101, 67, 33, 255}},
    .Fire = {{255, 0, 0, 255}, {255, 69, 0, 255}, {255, 140, 0, 255}, {255, 215, 0, 255}},
    .Steam = {{255, 255, 253, 255}, {230, 230, 230, 255}, {240, 240, 240, 255}, {220, 220, 220, 255}},
    .Plasma = {{255, 0, 255, 255}, {200, 0, 200, 255}, {255, 100, 255, 255}, {180, 0, 180, 255}},
    .Lava = {{139, 0, 0, 255}, {178, 34, 34, 255}, {205, 92, 92, 255}, {255, 99, 71, 255}},
    .Powder = {{70, 70, 70, 255}, {80, 80, 80, 255}, {90, 90, 90, 255}, {100, 100, 100, 255}},
    .Boom = {{254, 0, 0, 255}, {255, 50, 50, 255}, {240, 0, 0, 255}, {255, 100, 100, 255}},
    .Petrol = {{73, 77, 43, 255}, {85, 90, 50, 255}, {65, 70, 40, 255}, {95, 100, 55, 255}},
    .Acid = {{0, 255, 0, 255}, {50, 255, 50, 255}, {0, 200, 0, 255}, {100, 255, 100, 255}},
    .Iron = {{80, 80, 59, 255}, {90, 90, 65, 255}, {70, 70, 55, 255}, {100, 100, 75, 255}},
    .Snow = {{255, 255, 254, 255}, {240, 248, 255, 255}, {245, 245, 245, 255}, {255, 250, 250, 255}},
    .KnightDebris = {{115, 12, 24, 255}, {152, 22, 35, 255}, {188, 39, 49, 255}, {220, 69, 69, 255}},
    .OgreDebris = {{109, 8, 27, 255}, {145, 18, 39, 255}, {183, 34, 54, 255}, {216, 63, 74, 255}},
    .Ground = {{139, 90, 43, 255}, {160, 120, 80, 255}, {188, 143, 86, 255}, {205, 170, 125, 255}},
    .Grass = {{25, 89, 5, 255}, {55, 120, 15, 255}, {85, 160, 45, 255}, {115, 185, 70, 255}},
    .Glass = {{118, 184, 196, 190}, {158, 217, 224, 180}, {75, 137, 158, 210}, {205, 238, 239, 190}},
    .Blood = {{107, 8, 25, 255}, {143, 14, 32, 255}, {181, 31, 48, 255}, {211, 54, 65, 255}},
    .Potion = {{205, 54, 146, 255}, {230, 86, 170, 255}, {246, 133, 195, 255}, {179, 38, 122, 255}},
}

inside :: proc(x, y: int) -> bool { return x >= 0 && x < WORLD_W && y >= 0 && y < WORLD_H }
index :: proc(x, y: int) -> int { return y * WORLD_W + x }

