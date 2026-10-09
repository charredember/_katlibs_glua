local SYSTEM_NAME = "KNetChannel"
if SERVER then util.AddNetworkString(SYSTEM_NAME) end

local function netStart(syncedToken,callback,...)
    net.Start(SYSTEM_NAME)
    syncedToken:WriteToNet()

    local bytesUsedStart = net.BytesWritten()
    callback(...)
    return net.BytesWritten() - bytesUsedStart
end

local function netSend(players)
    if CLIENT then
        net.SendToServer()
        return
    end

    if players ~= nil then
        net.Send(players)
        return
    end

    net.Broadcast()
end

local getPriv
---SHARED<br/>
---A throttled net channel that can queue messages to send over time.<br/>
---Multiple differently throttled channels can send to the same receiver.
---@class KNetChannel
---@overload fun(syncedToken: KSyncedToken, burstLimit: number, regenRate: number, unreliable: boolean?): KNetChannel
KNetChannel,getPriv = KClass(function(syncedToken,burstLimit,regenRate,unreliable)
    return {
        SyncedToken = syncedToken,
        Queue = KQueue(),
        TokenBucket = KTimeUtils.TokenBucket(burstLimit,regenRate,true),
        BurstLimit = burstLimit,
        Unreliable = unreliable and true or false,
    }
end)

local activeChannels = setmetatable({},{__mode = "v"})

---SHARED<br/>
---Send a message over the net channel.<br/>
---<b>Do not call net.Start(), net.Broadcast(), net.Send(), or net.SendToServer() in the callback!</b>
---@param callback function
---@param players Player | Player[] | CRecipientFilter | nil
---@param ... any Parameters to pass to callback.
---@return boolean sent Whether the message was sent immediately
function KNetChannel:Send(callback,players,...)
    local priv = getPriv(self)

    local cost = netStart(priv.SyncedToken,callback,...)
    if cost > priv.BurstLimit then
        net.Abort()
        error(string.format("Net channel burst limit exceeded! (%d > %d)",cost,priv.BurstLimit))
    end

    local queue = priv.Queue
    local canSend = priv.TokenBucket(cost)
    if queue:Any() or not canSend then
        if priv.Unreliable then
            net.Abort()
            return false
        end

        queue:PushRight({
            Cost = cost,
            Callback = callback,
            Args = {...},
            Players = players,
        })
        activeChannels[self] = true

        net.Abort()
        return false
    end

    netSend(players)
    return true
end

---SHARED<br/>
---Empties the channel of any queued messages.<br/>
function KNetChannel:Flush()
    getPriv(self).Queue = KQueue()
end

hook.Add("Tick",SYSTEM_NAME,function()
    for channel,_ in pairs(activeChannels) do
        local priv = getPriv(channel)
        local queue = priv.Queue

        if not queue:Any() then
            activeChannels[channel] = nil
            continue
        end

        local message = queue:GetLeft()
        if not priv.TokenBucket(message.Cost) then continue end

        netStart(priv.SyncedToken,message.Callback,unpack(message.Args))
        netSend(message.Players)
        queue:PopLeft()
    end
end)

local callbacks = {}
---SHARED<br/>
---Sets a receiver for the net channel.<br/>
---@param syncedToken KSyncedToken
---@param callback fun(len: number, ply: Player)
function KNetChannel.Receive(syncedToken,callback)
    callbacks[syncedToken] = callback
end

net.Receive(SYSTEM_NAME,function(len,ply)
    local syncedToken = KSyncedToken.ReadFromNet()
    local callback = callbacks[syncedToken]
    if callback then callback(len,ply) end
end)