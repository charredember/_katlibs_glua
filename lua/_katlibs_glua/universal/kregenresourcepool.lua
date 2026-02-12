if KRegenResourcePool then return end

local m_min = math.min
local Tick_Regen

local regenerating = setmetatable({},{__mode = "k"})

local getPriv
---@class KRegenResourcePool
---A number value that regenerates over time and can be used.
---@overload fun(max: number, regenRatePerSecond: number): KRegenResourcePool
---@return KRegenResourcePool KRegenResourcePool
KRegenResourcePool,getPriv = KClass(function(max,regenRatePerSecond)
    KError.ValidateArg(1,"max",KVarCondition.NumberGreaterOrEqual(max,0))
    KError.ValidateArg(2,"regenRatePerSecond",KVarCondition.NumberGreaterOrEqual(regenRatePerSecond,0))

    return {
        Amount = max,
        Max = max,
        RegenRatePerTick = regenRatePerSecond * engine.TickInterval(),
        Hooks = {},
    }
end)

---Uses the resource pool with the specified cost.
---@param cost number
---@return boolean success
function KRegenResourcePool:Use(cost)
    local priv = getPriv(self)
    KError.ValidateArg(1,"cost",KVarCondition.NumberGreaterOrEqual(cost,0))

    regenerating[priv] = true
    hook.Add("Tick","KRegenResourcePool",Tick_Regen)

    local val = priv.Amount - cost
    if val < 0 then return false end
    priv.Amount = val

    return true
end

---Gets the maximum value of this resource pool.
---@return number max
function KRegenResourcePool:GetMax()
    return getPriv(self).Max
end

---Gets the current value of this resource pool.
---@return number value
function KRegenResourcePool:Count()
    return getPriv(self).Amount
end

---Adds a hook to this resource pool.<br>
---Automatically clears if this object is garbage collected.
---@param key string
---@param func function
function KRegenResourcePool:SetHook(key,func)
    KError.ValidateArg(1,"key",KVarCondition.String(key))
    if func ~= nil then KError.ValidateArg(2,"func",KVarCondition.Function(func)) end

    getPriv(self).Hooks[key] = func
end

function Tick_Regen()
    if not next(regenerating) then
        hook.Remove("Tick","KRegenResourcePool")
        return
    end

    for priv,_ in pairs(regenerating) do
        local max = priv.Max
        local val = m_min(priv.Amount + priv.RegenRatePerTick,max)

        priv.Amount = val

        if val == max then regenerating[priv] = nil end

        for _,func in pairs(priv.Hooks) do
            func(val)
        end
    end
end