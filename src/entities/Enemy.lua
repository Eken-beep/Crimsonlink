local assets = require("src.Assets")

return {
    position = {x = 0, y = 0},
    velocity = {x = 0, y = 0},
    health = {hp = 100, maxHp = 100},
    sprite = assets.enemies[1],
    hitbox = {w = 50, h = 50},
    enemy = true,
    movementspeed = 40,
    collidable = true,
    ai = {
        difficulty = 1,
        dormant = true
    }
}
