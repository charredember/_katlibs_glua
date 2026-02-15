if KNetStream then return end

local MAX_BYTES_PER_SECOND = 10e3
local MAX_CHUNKS = 10e3

local NETSTRING = "KNetStream"
if SERVER then util.AddNetworkString(NETSTRING) end

--SHARED, STATIC<br>
--A static net stream implementation.
KNetStream = {}

--TODO: Make instanced

do
    local limiter = KRegenResourcePool(MAX_BYTES_PER_SECOND,MAX_BYTES_PER_SECOND)
    local netThrottler = KFuncThrottler(limiter)

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

    local function sendChunk(chunk,players)
        net.Start(NETSTRING)
        net.WriteBool(false)
        net.WriteData(chunk)
        netSend(players)
    end

    ---SHARED,STATIC<br>
    ---Queue data to be sent to the opposite realm<br>
    ---@param id string
    ---@param data string
    function KNetStream.SendData(id,data,players)
        KError.ValidateArg(1,"id",KVarCondition.String(id))
        KError.ValidateArg(2,"data",KVarCondition.String(data))

        local dataSize = #data
        local numChunks = math.ceil(dataSize / MAX_BYTES_PER_SECOND)
        assert(numChunks < MAX_CHUNKS,string.format("size cannot be greater than %d bytes!",MAX_BYTES_PER_SECOND * MAX_CHUNKS))

        netThrottler:Execute(#id + 33,function()
            net.Start(NETSTRING)
            net.WriteBool(true)
            net.WriteString(id)
            net.WriteUInt(numChunks,32)
            netSend(players)
        end)

        for i = 0, numChunks - 1 do
            local chunkSize = math.min(dataSize,MAX_BYTES_PER_SECOND)
            local curr = MAX_BYTES_PER_SECOND * i
            local chunk = data:sub(curr + 1, curr + chunkSize)
            netThrottler:Execute(chunkSize,sendChunk,chunk,players)
        end
    end
end

do
    local receivers = {}

    ---SHARED,STATIC<br>
    ---Set a callback for when a stream is fully received from the opposite realm<br>
    ---@param id string
    ---@param callback fun(data : string, ply : Player?)?
    function KNetStream.ReceiveData(id,callback)
        KError.ValidateArg(1,"id",KVarCondition.String(id))
        if callback then KError.ValidateArg(2,"callback",KVarCondition.Function(callback)) end

        receivers[id] = callback
    end

    local streamData = {}
    local function getStreamData(ply)
        if SERVER then return streamData[ply] end
        return streamData
    end

    local function setStreamData(tab,ply)
        if SERVER then streamData[ply] = tab return end
        streamData = tab
    end

    net.Receive(NETSTRING,function(len,ply)
        local header = net.ReadBool()
        if header then
            local id = net.ReadString()
            local numChunks = net.ReadUInt(32)

            setStreamData({
                ID = id,
                NumChunks = numChunks,
                Chunks = {},
            },ply)
        else --receive data
            local data = getStreamData(ply)
            if not data then return end

            local chunks = data.Chunks
            local chunk = net.ReadData((len - 1) / 8)

            table.insert(chunks,chunk)

            if SERVER and #chunks > MAX_CHUNKS then
                setStreamData(nil,ply)
                error(string.format("%s is sending more chunks than the MAX_CHUNKS limit! possible exploiter??",ply:SteamID()))
            end

            if #chunks >= data.NumChunks then
                local cb = receivers[data.ID]
                if cb then cb(table.concat(chunks),ply) end
                setStreamData(nil,ply)
            end
        end
    end)
end