local tiny = require("lib.tiny")

local inputSystem = tiny.processingSystem()
inputSystem.filter = tiny.requireAll("controllable")
inputSystem.updateSystem = true

function inputSystem:process(e)
    local mKeys = Input.states.keyboard
    local b = Input.bindings.keyboard
    -- movement
     if mKeys[b.walkForward] then
         e.velocity.y = -e.movementspeed
     elseif mKeys[b.walkBackward] then
         e.velocity.y = e.movementspeed
     else e.velocity.y = 0
     end
     if mKeys[b.walkLeft] then
         e.velocity.x = -e.movementspeed
     elseif mKeys[b.walkRight] then
         e.velocity.x = e.movementspeed
     else e.velocity.x = 0
     end
end

return inputSystem
