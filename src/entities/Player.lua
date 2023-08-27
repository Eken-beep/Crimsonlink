local assets = require("src.Assets")
local player = {
    position = {x=0,y=0},
    velocity = {x=30,y=30},
    health = {hp = 100, maxHp = 100},
    hitbox = {w=10,h=10},
    inventory = {},
    animation = assets.playerAnimation,

    collidable = true,
    alive = true
}

return player
