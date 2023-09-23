local assets = require("src.Assets")

return {
    position = {x = 0, y = 0},
    velocity = {x = 0, y = 0},
    sprite = assets.enemies[1],
    enemy = true,
    movementspeed = 40,
    ai = {
        difficulty = 1,
        dormant = true
    }
}
