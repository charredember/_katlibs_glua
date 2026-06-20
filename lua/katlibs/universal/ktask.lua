---@class KTaskToken
---@field YieldAndReportProgress fun(self: KTaskToken, ratio: number) Yield the current coroutine and report the progress of the current execution layer.
---@field GetChildToken fun(self: KTaskToken): KTaskToken Gets a token to pass into the next execution layer.
---@field IsCancellationRequested fun(self: KTaskToken): boolean Check whether this task has been cancelled by the top layer.

local co_yield = coroutine.yield
local m_min = math.min

local getPriv
---SHARED<br/>
---An object used to track and control the progress of an ongoing coroutine at multiple layers of execution.<br/><br/>
---This is a co-operative mechanism.<br/>
---It requires all parties to co-operate in order to work correctly.<br/>
---To work correctly, cancellation chains must be properly propogated and coroutines should be allowed to end gracefully from the outside.
---@class KTask
---@overload fun(): KTask
KTask,getPriv = KClass(function()
    return {
        Progress = {},
        CancellationRequested = false,
    }
end)

local getToken
---@return KTaskToken
function getToken(stackLevel,progress,isCancellationRequested)
    return {
        YieldAndReportProgress = function(self,ratio)
            progress[stackLevel] = ratio
            co_yield()
        end,

        GetChildToken = function(self)
            return getToken(stackLevel + 1, progress, isCancellationRequested)
        end,

        IsCancellationRequested = isCancellationRequested,
    }
end

---SHARED<br/>
---Returns a token for this task to pass into the first layer of execution.
---@return KTaskToken
function KTask:GetToken()
    local priv = getPriv(self)
    return getToken(1,priv.Progress,function() return priv.CancellationRequested end)
end

---SHARED<br/>
---Reports the current progress of the task.
function KTask:GetProgress()
    local progress = getPriv(self).Progress

    local ratio = 0
    for i = 1,#progress do
        local layerProgress = progress[i] or 0
        ratio = ratio + layerProgress / 10 ^ (i - 1)
        if layerProgress == 1 then break end
    end

    return m_min(ratio,1)
end

---SHARED<br/>
---Cancels this task and reports progress to all layers.
function KTask:Cancel()
    getPriv(self).CancellationRequested = true
end