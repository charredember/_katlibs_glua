if KAutoLoader then return end

---SHARED,STATIC<br>
---Loader for directories of lua files.
KAutoLoader = {}

local function nop() end

local fileActions
if SERVER then
	fileActions = {
		sv = include,
		cl = AddCSLuaFile,
		sh = function(path)
			AddCSLuaFile(path)
			include(path)
		end,
	}
elseif CLIENT then
	fileActions = {
		sv = nop,
		cl = include,
		sh = include,
	}
end

local function AssertValidRealm(val)
	return {fileActions[val] ~= nil,"\"sv\", \"cl\", \"sh\""}
end

local function addFile(file,directory,realm)
	if not realm then realm = string.lower(string.Left(file, 2)) end

	local action = fileActions[realm]
	action(directory .. file)
end

---Include all lua files in a directory<br>
---
---params:
--- - string? Realm [sv, cl, sh]
--- - bool? Recursive
---@param directory string
---@param params table?
function KAutoLoader.IncludeDir(directory,params)
	params = params or {}

	KError.ValidateArg(1,"directory",KVarCondition.StringNotEmpty(directory))

	local realm = params.Realm
	if realm then KError.ValidateArg(2,"params.Realm",AssertValidRealm(realm)) end

	local recursive = params.Recursive == nil and true or false
	KError.ValidateArg(2,"params.Recursive",KVarCondition.Bool(recursive))

	directory = directory .. "/"
	local files, directories = file.Find(directory .. "*","LUA")

	for _,v in ipairs(files) do
		if not string.EndsWith(v,".lua") then continue end
		addFile(v,directory,realm)
	end

	if not recursive then return end

	for _,v in ipairs(directories) do
		KAutoLoader.IncludeDir(directory .. v,params)
	end
end