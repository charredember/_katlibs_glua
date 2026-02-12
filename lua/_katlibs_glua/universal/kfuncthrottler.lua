if KFuncThrottler then return end

local uidItr = 0

local getPriv
---@class KFuncThrottler
---@overload fun(limiter: KRegenResourcePool): KFuncThrottler
---@return KFuncThrottler KFuncThrottler
---Controls how fast a function is executed based on a resource.
KFuncThrottler,getPriv = KClass(function(limiter)
    KError.ValidateArg(1,"limiter",KVarCondition.TableMeta(limiter,KRegenResourcePool,"KRegenResourcePool"))

    uidItr = uidItr + 1
    return {
        Limiter = limiter,
        Queue = KQueue(),
        HookName = "KFuncThrottler" .. uidItr,
    }
end)

local function getWeakReference(object)
    local weakReference = setmetatable({object},{__mode = "v"})
    return function() return weakReference[1] end
end

---Attempt to execute a function.<br>
---If resources do not allow, the function will instead be queued for when the resources are available.
---@param cost number
---@param func function
---@param ... any Arguments to pass.
function KFuncThrottler:Execute(cost,func,...)
    local priv = getPriv(self)
    local queue = priv.Queue

    local limiter = priv.Limiter
    local max = limiter:GetMax()
    KError.ValidateArg(1,"cost",KVarCondition.NumberInRange(cost,0,max))
    KError.ValidateArg(2,"func",KVarCondition.Function(func))

    if not queue:Any() and limiter:Use(cost) then
        func(...)
        return
    end

    queue:PushRight({cost,func,{...}})

    ---do not hold a direct reference to the limiter as an upvalue
    ---so that it will properly cleanup if our parent throttler goes out of scope
    local getLimiter = getWeakReference(limiter)

    local hookName = priv.HookName
    limiter:SetHook(hookName,function(currVal)
        local queued = queue:GetLeft()

        local limiterReference = getLimiter()
        if not limiterReference then return end

        if not queued then
            limiterReference:SetHook(hookName,nil)
            return
        end

        local currCost = queued[1]
        if currCost > currVal then return end

        limiterReference:Use(currCost)
        queued[2](unpack(queued[3]))
        queue:PopLeft()
    end)
end

---Resets the internal queue, clearing any queued operations.
function KFuncThrottler:Clear()
    local priv = getPriv(self)
    priv.Queue = KQueue
    priv.Limiter:SetHook(priv.HookName,nil)
end