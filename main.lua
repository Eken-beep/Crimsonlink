require("ecs.ecs")
require("player")

function love.update(dt)
end

function love.draw()
end

function love.load()
    World:create({
        ["position"] = {x=0,y=0},
        ["velocity"] = {x=0,y=0},
        ["health"]   = 0,
        ["player"]   = true,
        ["enemy"]    = true,
        ["bullet"]   = true,
        ["particle"] = 0,
        ["hitbox"]   = {w=0,h=0},
        ["static"]   = true
    })
end
