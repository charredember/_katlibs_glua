if KClientInit then return end

---SHARED, STATIC<br/>
---Quick and convenient sync the client with the server on choice data.<br/>
---
---Hooks:
--- - KOnClientInit(Player ply)
KClientInit = {}

local NETSTRING = "KClientInit"

local h_Run = hook.Run
local n_Start = net.Start
local n_WriteString = net.WriteString
local n_ReadString = net.ReadString
local n_Send = net.Send
local n_SendToServer = net.SendToServer
local pairs = pairs

local receivers = {}

if SERVER then
	util.AddNetworkString(NETSTRING)

	local alreadyLoaded = {}
	hook.Add("PlayerDisconnected","KClientInit",function(ply)
		alreadyLoaded[ply] = nil
	end)

	net.Receive("KClientInit",function(_,ply)
		if alreadyLoaded[ply] then return end
		alreadyLoaded[ply] = true

		h_Run("KOnClientInit",ply)

		for key,func in pairs(receivers) do
			n_Start(NETSTRING)
			n_WriteString(key)
			func()
			n_Send(ply)
		end
	end)

	---SERVER<br/>
	---Register a netcode callback to send to the client when it initializes.<br/>
	---Do not start or send net, it is automatically handled.
	---@param key string
	---@param func function
	function KClientInit.SendClientData(key,func)
		KError.ValidateArg("key",KVarConditions.String(key))
		KError.ValidateArg("func",KVarConditions.Function(func))

		receivers[key] = func
	end
elseif CLIENT then
	hook.Add("InitPostEntity","KClientInit",function()
		n_Start(NETSTRING)
		n_SendToServer()
	end)

	---CLIENT<br/>
	---Register a netcode callback to receive from the server when it initializes.<br/>
	---Do not start or send net, it is automatically handled.
	---@param key string
	---@param func function
	function KClientInit.ReceiveServerData(key,func)
		KError.ValidateArg("key",KVarConditions.String(key))
		KError.ValidateArg("func",KVarConditions.Function(func))

		receivers[key] = func
	end

	net.Receive("KClientInit",function()
		local func = receivers[n_ReadString()]
		if func then func() end
	end)
end