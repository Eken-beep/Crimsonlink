local tiny = require("lib.tiny")

local movement = tiny.processingSystem()
movement.filter = tiny.requireAll("position", "velocity")
function movement:process(e,dt)
    e.position.x = e.position.x + e.velocity.x * dt
    e.position.y = e.position.y + e.velocity.y * dt
end

return movement
