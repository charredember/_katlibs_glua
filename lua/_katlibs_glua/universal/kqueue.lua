if KQueue then return end

local getPriv
---@class KQueue
---@overload fun(): KQueue
---@return KQueue KQueue
---SHARED<br>
---A queue data structure.
KQueue,getPriv = KClass(function()
    return {
        first = 0,
        last = -1,
        empty = true,
    }
end)

---SHARED<br>
function KQueue:Any()
    local priv = getPriv(self)

    return priv.first <= priv.last
end

---SHARED<br>
function KQueue:Count()
    local priv = getPriv(self)

    local ct = priv.last - priv.first
    if ct < 0 then return 0 end
    return ct + 1
end

---SHARED<br>
function KQueue:PushLeft(value)
    local priv = getPriv(self)

    local first = priv.first - 1
    priv.first = first
    priv[first] = value
end

---SHARED<br>
function KQueue:PushRight(value)
    local priv = getPriv(self)

    local last = priv.last + 1
    priv.last = last
    priv[last] = value
end

---SHARED<br>
function KQueue:GetLeft()
    local priv = getPriv(self)

    return priv[priv.first]
end

---SHARED<br>
function KQueue:GetRight()
    local priv = getPriv(self)

    return priv[priv.last]
end

---SHARED<br>
function KQueue:PopLeft()
    local priv = getPriv(self)

    local first = priv.first
    assert(priv.first <= priv.last,"list empty")
    local value = priv[first]
    priv[first] = nil
    priv.first = first + 1

    return value
end

---SHARED<br>
function KQueue:PopRight()
    local priv = getPriv(self)

    local last = priv.last
    assert(priv.first <= priv.last,"list empty")
    local value = priv[last]
    priv[last] = nil
    priv.last = last - 1

    return value
end

local noOp = function() return nil end

---SHARED<br>
---Returns an iterator function for this queue.
function KQueue:Iterator()
    local priv = getPriv(self)

    if priv.first > priv.last then return noOp end

    local curr = priv.first - 1
    return function()
        curr = curr + 1
        local val = priv[curr]
        if not val then return end
        return curr,val
    end
end