local tiny = require("lib.tiny")

local stepAi = tiny.processingSystem()
stepAi.filter = tiny.requireAll("position", "velocity", "ai")
stepAi.updateSystem = true

function stepAi:process(e)
    local angle = math.atan2((PlayerY+25)-e.position.y,
                             (PlayerX+16)-e.position.x)
    e.velocity.x, e.velocity.y =
        e.movementspeed * math.cos(angle),
        e.movementspeed * math.sin(angle)
end

return stepAi
