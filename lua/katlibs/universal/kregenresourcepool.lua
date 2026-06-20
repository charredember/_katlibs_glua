if KRegenResourcePool then return end

local m_min = math.min
local Tick_Regen

local regenerating = setmetatable({},{__mode = "k"})

local getPriv
---SHARED<br/>
---A number value that regenerates over time and can be used.
---@class KRegenResourcePool
---@overload fun(max: number, regenRatePerSecond: number, allowDebt?: boolean): KRegenResourcePool
KRegenResourcePool,getPriv = KClass(function(max,regenRatePerSecond,allowDebt)
    KError.ValidateArg("max",KVarConditions.NumberGreaterOrEqual(max,0))
    KError.ValidateArg("regenRatePerSecond",KVarConditions.NumberGreaterOrEqual(regenRatePerSecond,0))

    return {
        Amount = max,
        Max = max,
        AllowDebt = allowDebt or false,
        RegenRatePerTick = regenRatePerSecond * engine.TickInterval(),
        Hooks = {
            Think = {},
            OnFull = {},
            OnEmpty = {},
        },
    }
end)

local function callHook(hooks,val)
    for _,func in pairs(hooks) do
        func(val)
    end
end

---SHARED<br/>
---Uses the resource pool with the specified cost.
---@param cost number
---@return boolean success
function KRegenResourcePool:Use(cost)
    local priv = getPriv(self)
    KError.ValidateArg("cost",KVarConditions.NumberGreaterOrEqual(cost,0))

    regenerating[priv] = true
    hook.Add("Tick","KRegenResourcePool",Tick_Regen)

    local amount = priv.Amount
    if amount < 0 then return false end

    local newVal = amount - cost
    if newVal <= 0 then
        if newVal < 0 and not priv.AllowDebt then return false end
        callHook(priv.Hooks.OnEmpty,newVal)
    end

    priv.Amount = newVal
    return true
end

---SHARED<br/>
---Gets the maximum value of this resource pool.
---@return number max
function KRegenResourcePool:GetMax()
    return getPriv(self).Max
end

---SHARED<br/>
---Gets the current value of this resource pool.
---@return number value
function KRegenResourcePool:Count()
    return getPriv(self).Amount
end

---@alias KRegenResourcePoolHook
---| '"Think"' #fun(value: number) - Called every tick while the pool is regenerating.
---| '"OnFull"' #fun(value: number) - Called once when the pool is filled.
---| '"OnEmpty"' #fun(value: number) - Called once when the pool is depleted.

---CLIENT<br/>
---Register a hook with this KNWEntity.<br/>
---Set func to nil to remove a hook.
--- @param hooktype KRegenResourcePoolHook
--- @param id any
--- @param func function?
function KRegenResourcePool:SetHook(hooktype,id,func)
    KError.ValidateArg("key",KVarConditions.String(id))
    KError.ValidateNullableArg("func",KVarConditions.Function(func))

    local hookTab = getPriv(self).Hooks[hooktype]
    if not hookTab then return end
    hookTab[id] = func
end

function Tick_Regen()
    if not next(regenerating) then
        hook.Remove("Tick","KRegenResourcePool")
        return
    end

    for priv,_ in pairs(regenerating) do
        local hooks = priv.Hooks
        local max = priv.Max
        local val = m_min(priv.Amount + priv.RegenRatePerTick,max)

        priv.Amount = val

        if val == max then
            callHook(hooks.OnFull,val)
            regenerating[priv] = nil
        end

        callHook(hooks.Think,val)
    end
end