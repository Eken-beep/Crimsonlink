-- Number of room, hub is 0, Room is of boundaries(from top left and clockwise) and a map fill
RW = 1920
RH = 1080
if W/1920 > H/1080 then
    RW = 1920*(H/1080)
    RH = H
else
    RW = W
    RH = 1080*(W/1920)
end

RX, RY = W/2 - RW/2, H/2 - RH/2
Rooms = { [0] = {boundaries = {}}
        , {}
        }

Maps = { hub = { room = Rooms[0]}
       , floor1 = { Rooms[1]}
       }