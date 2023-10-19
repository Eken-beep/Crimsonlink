local lib = {}

lib.map = function(f,t)
    for i=1, #t do
        t[i] = f(t[i])
    end
    return t
end

lib.distance = function(x1,y1, x2,y2)
    return math.sqrt(
        math.pow(x1+x2,2) +
        math.pow(y1+y2,2)
    )
end

return lib
