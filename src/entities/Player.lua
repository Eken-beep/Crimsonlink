local assets = require("src.Assets")
local player = {
    position = {x=0,y=0},
    velocity = {x=0,y=0},
    health = {hp = 100, maxHp = 100},
    hitbox = {w=10,h=10},
    inventory = {},
    animation = assets.playerAnimation,
    movementspeed = 40,

    collidable = true,
    alive = true,
    controllable = true
}

return player
