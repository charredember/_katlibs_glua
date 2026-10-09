local SYSTEM_NAME = "KSyncedToken"
local BIT_SIZE = 16

local uintTokenLookup = setmetatable({},{__mode = "v"})
local stringTokenLookup = setmetatable({},{__mode = "v"})

local assertValidName
local createNewToken,remove

local getPriv
---SHARED<br/>
---A token that is a unique string that is synced from the server to the client using a uint to decrease bandwith.<br/>
---<br/>
---Tokens are:
--- - Alphanumeric characters and underscores only
--- - Max 30 characters
--- - Case insensitive
---@class KSyncedToken
KSyncedToken,getPriv = KClass(nil,{
	Destructor = function(priv)
		remove(priv)
	end,
})

---@class KReservedSyncedToken : KSyncedToken

local instantiate = getPriv(KSyncedToken).Instantiate

---SHARED,STATIC<br/>
---Registers a new synced token, or an active token with the same identifier.<br/>
---If the all token handles referencing the identifier are cleaned up by the garbage collector, the token will become invalid.<br/>
---@param identifier string The identifier that will be used to sync the token with the client.<br/>
---@return KSyncedToken
function KSyncedToken.Get(identifier)
	assertValidName(identifier)

	identifier = string.lower(identifier)
	return stringTokenLookup[identifier] or createNewToken(identifier)
end

---SHARED,STATIC<br/>
---Reserves a new synced token.<br/>
---Only one reserved token can exist at a time.<br/>
---Reserved tokens will not collide with regular tokens from KSyncedToken.Get()<br/>
---If the token handle referencing the identifier is cleaned up by the garbage collector, the token will become invalid.<br/>
---@param identifier string The identifier that will be used to sync the token with the client.<br/>
---@return KReservedSyncedToken
function KSyncedToken.Reserve(identifier)
	assertValidName(identifier)

	local uniqueIdentifier = "!" .. string.lower(identifier)
	assert(stringTokenLookup[uniqueIdentifier] == nil,
		string.format("Reserved token cannot be created - identifier [%s] already in use elsewhere",identifier))
	return createNewToken(uniqueIdentifier)
end

---SHARED,STATIC<br/>
---Reads a token from the net stream.<br/>
---Returns nil if the token is invalid (no active handles in this realm).
---@return KSyncedToken?
function KSyncedToken.ReadFromNet()
	return uintTokenLookup[net.ReadUInt(BIT_SIZE)]
end

---SHARED<br/>
---Writes the token to the net stream.<br/>
function KSyncedToken:WriteToNet()
	local uint = getPriv(self).UInt
	assert(uint ~= nil,"Token invalid!")
	net.WriteUInt(uint,BIT_SIZE)
end

---SHARED<br/>
---Returns whether the token is valid on the serverside.<br/>
function KSyncedToken:IsValid()
	return getPriv(self).UInt ~= nil
end

function assertValidName(identifier)
	assert(identifier:match("^[A-Za-z0-9_]+$") ~= nil,"Tokens may only contain alphanumeric characters and underscores!")
	KError.ValidateArg("identifier",KVarConditions.StringLengthLessOrEqual(identifier,30))
end

if SERVER then
	util.AddNetworkString(SYSTEM_NAME)

	local uidItr = -1
	function createNewToken(identifier)
		uidItr = uidItr + 1
		local uint = uidItr
		local token = instantiate({
			Identifier = identifier,
			UInt = uint,
		})

		uintTokenLookup[uint] = token
		stringTokenLookup[identifier] = token

		local priv = getPriv(token)
		net.Start(SYSTEM_NAME)
		net.WriteBool(true)
		net.WriteString(priv.Identifier)
		net.WriteUInt(priv.UInt,BIT_SIZE)
		net.Broadcast()

		return token
	end

	function remove(priv)
		net.Start(SYSTEM_NAME)
		net.WriteBool(false)
		net.WriteString(priv.Identifier)
		net.WriteUInt(priv.UInt,BIT_SIZE)
		net.Broadcast()
	end

	KClientInit.Register(SYSTEM_NAME,function(ply)
		for _,token in pairs(uintTokenLookup) do
			local priv = getPriv(token)
			net.Start(SYSTEM_NAME)
			net.WriteBool(true)
			net.WriteString(priv.Identifier)
			net.WriteUInt(priv.UInt,BIT_SIZE)
			net.Send(ply)
		end
	end)
elseif CLIENT then
	function createNewToken(identifier)
		local token = instantiate({
			Identifier = identifier,
			--UInt
		})

		stringTokenLookup[identifier] = token
		return token
	end

	function remove(priv) end --noop

	local activeTokens = {} --keeps GC from cleaning it up so long as its active on the server
	net.Receive(SYSTEM_NAME,function()
		local adding = net.ReadBool()
		local identifier = net.ReadString()
		local uint = net.ReadUInt(BIT_SIZE)

		local token = stringTokenLookup[identifier] or createNewToken(identifier)
		if adding then
			activeTokens[identifier] = token
			uintTokenLookup[uint] = token
			getPriv(token).UInt = uint
		else
			activeTokens[identifier] = nil
			uintTokenLookup[uint] = nil
			stringTokenLookup[identifier] = nil
			getPriv(token).UInt = nil
		end
	end)
end