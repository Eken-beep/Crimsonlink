local tiny = require("lib.tiny")

local movement = tiny.processingSystem()
movement.filter = tiny.requireAll("position", "velocity")
movement.updateSystem = true

function movement:process(e,dt)
    e.position.x = e.position.x + e.velocity.x * dt
    e.position.y = e.position.y + e.velocity.y * dt
    if e.time then
        e.time = e.time + dt
        if e.time > e.lifetime then
            tiny.removeEntity(World, e)
        end
    end
end

return movement
