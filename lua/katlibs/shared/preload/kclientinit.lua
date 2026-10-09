---SHARED, STATIC<br/>
---Utility functions for initializing client-side code.<br/>
KClientInit = {}

local SYSTEM_NAME = "KClientInit"

if SERVER then
	local logger = KLogger(SYSTEM_NAME)
	util.AddNetworkString(SYSTEM_NAME)

	local alreadyLoaded = {}
	hook.Add("PlayerDisconnected",SYSTEM_NAME,function(ply)
		alreadyLoaded[ply] = nil
	end)

	---SERVER<br/>
	---Utility for synchronizing order of initialization for libraries that network from server to client.
	KClientInit = {}

	local function topologicalSort(items)
		local itemLookup = {}
		for _,list in ipairs(items) do
			itemLookup[list.Library] = list
		end

		local visited = {}
		local visiting = {}
		local result = {}

		local function visit(list)
			if not list then return end
			if visited[list] then return end
			if visiting[list] then error("Cannot add library registration - results in circular dependencies.") end

			visiting[list] = true

			for _,dependencyLibrary in pairs(list.Dependencies) do
				local dependencyItem = itemLookup[dependencyLibrary]
				visit(dependencyItem)
			end

			visiting[list] = nil
			visited[list] = true
			table.insert(result, list)
		end

		for _, list in ipairs(items) do
			visit(list)
		end

		return result
	end

	local registered = {}

	---SERVER<br/>
	---Register a library to send data to on client initialization.
	---@param library string
	---@param callback function
	---@param dependencies string[]?
	function KClientInit.Register(library,callback,dependencies)
		table.insert(registered,{
			Library = library,
			Callback = callback,
			Dependencies = dependencies or {},
		})

		registered = topologicalSort(registered)
	end

	---SERVER<br/>
	---Unregister a library to send data to on client initialization.
	function KClientInit.Unregister(library)
		for i = 1,#registered do
			if library == registered[i].Library then
				table.remove(registered,i)
				return
			end
		end
	end

	---SERVER<br/>
	---Returns the current load order of libraries.
	function KClientInit.GetLoadOrder()
		local result = {}

		for i = 1,#registered do
			result[i] = registered[i].Library
		end

		return result
	end

	net.Receive(SYSTEM_NAME,function(_,ply)
		if alreadyLoaded[ply] then return end
		alreadyLoaded[ply] = true

		ProtectedCall(hook.Run,"KClientPreInit",ply)

		for i = 1,#registered do
			ProtectedCall(registered[i].Callback,ply)
		end

		logger:LogConsole(string.format(
			"Initialized %i libraries for player %s.",#registered,ply:Nick()))

		ProtectedCall(hook.Run,"KOnClientInit",ply) -- Depreciated
		ProtectedCall(hook.Run,"KClientPostInit",ply)

		net.Start(SYSTEM_NAME)
		net.Send(ply)
	end)
elseif CLIENT then
	hook.Add("InitPostEntity",SYSTEM_NAME,function()
		ProtectedCall(hook.Run,"KClientPreInit")

		net.Start(SYSTEM_NAME)
		net.SendToServer()
	end)

	net.Receive(SYSTEM_NAME,function()
		ProtectedCall(hook.Run,"KClientPostInit")
	end)
end