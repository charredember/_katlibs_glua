if KQueue then return end

local getPriv
---@class KQueue
---@overload fun(): KQueue
---@return KQueue KQueue
---SHARED<br/>
---A queue data structure.
KQueue,getPriv = KClass(function()
    return {
        first = 0,
        last = -1,
        empty = true,
    }
end)

---SHARED<br/>
---Whether this queue contains any elements.<br/>
---COMPLEXITY: O(1) (cached)
function KQueue:Any()
    local priv = getPriv(self)

    return priv.first <= priv.last
end

---SHARED<br/>
---Returns the amount of elements in this queue.<br/>
---COMPLEXITY: O(1) (cached)
---@return integer
function KQueue:Count()
    local priv = getPriv(self)

    local ct = priv.last - priv.first
    if ct < 0 then return 0 end
    return ct + 1
end

---SHARED<br/>
---Pushes an element onto the left side of this queue.<br/>
---COMPLEXITY: O(1)
function KQueue:PushLeft(value)
    local priv = getPriv(self)

    local first = priv.first - 1
    priv.first = first
    priv[first] = value
end

---SHARED<br/>
---Pushes an element onto the right side of this queue.<br/>
---COMPLEXITY: O(1)
function KQueue:PushRight(value)
    local priv = getPriv(self)

    local last = priv.last + 1
    priv.last = last
    priv[last] = value
end

---SHARED<br/>
---Returns the left-most element in this queue.<br/>
---COMPLEXITY: O(1)
---@return any
function KQueue:GetLeft()
    local priv = getPriv(self)

    return priv[priv.first]
end

---SHARED<br/>
---Returns the right-most element in this queue.<br/>
---COMPLEXITY: O(1)
---@return any
function KQueue:GetRight()
    local priv = getPriv(self)

    return priv[priv.last]
end

---SHARED<br/>
---Removes and returns the left-most element in this queue.<br/>
---COMPLEXITY: O(1)
---@return any
function KQueue:PopLeft()
    local priv = getPriv(self)

    local first = priv.first
    assert(priv.first <= priv.last,"list empty")
    local value = priv[first]
    priv[first] = nil
    priv.first = first + 1

    return value
end

---SHARED<br/>
---Removes and returns the right-most element in this queue.<br/>
---COMPLEXITY: O(1)
---@return any
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

---SHARED<br/>
---Returns an iterator function for this queue.<br/>
---COMPLEXITY: O(n)
---@return fun(): integer?, any?
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