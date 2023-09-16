local tiny = require("lib.tiny")
local spawnBullet = tiny.processingSystem()

spawnBullet.filter = tiny.requireAll("velocity", "position", "controllable")
spawnBullet.updateSystem = true

function spawnBullet:process(e)
    for i,v in ipairs(Events) do
        if v() == "addBullet" then
            local angle = math.atan2(e.position.y-v.y,e.position.x-v.y)
            World:addEntity(setmetatable({
                parentIsPlayer = true,
                position = {x = e.position.x, y = e.position.y},
                velocity = {x = math.cos(angle)*-100,
                            y = math.sin(angle)*-100},
            },{ __index = require("src.entities.Bullet")}))
            table.remove(Events,i)
        end
    end
end

return spawnBullet
