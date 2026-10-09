---SHARED, STATIC<br/>
---Time related utilities for program control flow and animation.
KTimeUtils = {}

local m_min = math.min
local m_clamp = math.Clamp
local co_yield = coroutine.yield
local co_running = coroutine.running
local CurTime = CurTime
local SysTime = SysTime
local assert = assert

---SHARED, STATIC<br/>
---Returns a new lightweight tween function.
---Returns a number in the range [0-1] based on time since (object creation time + initial delay) over set duration.<br/>
---Starts at object creation time + initial delay.<br/>
---Uses CurTime().
---@param duration number
---@param startDelay number?
---@return fun(): number
function KTimeUtils.Tween(duration,startDelay)
    KError.ValidateArg("duration",KVarConditions.NumberGreater(duration,0))
    KError.ValidateNullableArg("startDelay",KVarConditions.NumberGreaterOrEqual(startDelay,0))
    if not startDelay then startDelay = 0 end

    local savedTime = CurTime() + startDelay
    local dt

    return function()
        dt = CurTime() - savedTime

        if dt < 0 then return 0 end
        if dt <= duration then return dt / duration end
        return 1
    end
end

---SHARED, STATIC<br/>
---A tween that runs inside a coroutine.<br/>
---Blocks the current thread until the duration has finished.<br/>
---Uses CurTime().
---@async
---@param duration number
---@param func fun(up: number,...)
function KTimeUtils.TweenAsync(duration,func,...)
    assert(co_running(),"TweenAsync called outside of coroutine!")
    KError.ValidateArg("duration",KVarConditions.NumberGreater(duration,0))
    KError.ValidateArg("func",KVarConditions.Function(func))

    local savedTime = CurTime()
    local dt

    while true do
        dt = CurTime() - savedTime

        if dt <= duration then
            func(dt / duration,...)
        else
            func(1,...)
            break
        end

        co_yield()
    end
end

---SHARED, STATIC<br/>
---Returns a new lightweight throttling function.
---After returning true once, it will return false until the interval passes, resetting it back to true.
---@param interval number
---@param startTrue boolean?
---@param useSysTime boolean?
---@return fun(): boolean
function KTimeUtils.IntervalTrigger(interval,startTrue,useSysTime)
    KError.ValidateArg("interval",KVarConditions.NumberGreater(interval,0))

    local time = useSysTime and SysTime or CurTime

    local savedTime = time()
    local t

    return function()
        if startTrue then
            startTrue = false
            return true
        end

        t = time()
        if (t - savedTime) > interval then
            savedTime = t
            return true
        end

        return false
    end
end

---SHARED, STATIC<br/>
---Returns a new lightweight token bucket function.<br/>
---@param burstLimit number
---@param regenRate number
---@param useSysTime boolean?
---@return fun(use: number): success: boolean, bucket: number
function KTimeUtils.TokenBucket(burstLimit,regenRate,useSysTime)
    KError.ValidateArg("burstLimit",KVarConditions.NumberGreater(burstLimit,0))
    KError.ValidateArg("regenRate",KVarConditions.NumberGreater(regenRate,0))

    local time = useSysTime and SysTime or CurTime

    local bucket = burstLimit
    local savedTime = time()
    local t

    return function(use)
        t = time()
        bucket = m_min(bucket + (t - savedTime) * regenRate,burstLimit)
        savedTime = t

        if use > bucket then return false,bucket end

        bucket = bucket - use
        return true,bucket
    end
end

---SHARED, STATIC<br/>
---Executes a function-wrapped coroutine until:
--- - A specified quota is reached.
--- - The coroutine returns a value that is not nil.
---
--- <br/>
--- Forwards the result from the called coroutine when the coroutine finishes.
---Uses SysTime().
---@param quota number
---@param coroutineFunc function
function KTimeUtils.RunWrappedCoroutineWithQuota(quota,coroutineFunc)
    local savedTime = SysTime()
    while true do
        local result = coroutineFunc()
        if result ~= nil then return result end
        if (SysTime() - savedTime) > quota then return end
    end
end

---SHARED, STATIC<br/>
---Creates a new quadratic ease function.<br/>
---@param power number
---@param easeStart number
---@return fun(up: number) : number
function KTimeUtils.QuadraticEaseInOut(power,easeStart)
    KError.ValidateArg("power",KVarConditions.NumberGreater(power,0))
    KError.ValidateArg("easeStart",KVarConditions.NumberInRange(easeStart,0,1))

    local easeInConstant = 1 / (easeStart ^ (power - 1))
    local easeOutConstant = (1 - easeStart) ^ (power - 1)
    return function(up)
        if up < easeStart then
            return easeInConstant * up ^ power
        else
            return 1 - (((1 - up) ^ power) / easeOutConstant)
        end
    end
end