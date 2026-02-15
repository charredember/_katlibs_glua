if KError then return end

AddCSLuaFile()

---SHARED,STATIC<br>
---Standardized errors
KError = {}

local isnumber = isnumber
local isstring = isstring
local istable = istable
local isentity = isentity
local IsValid = IsValid
local getmetatable = getmetatable
local s_format = string.format
local error = error

---SHARED,STATIC<br>
---Conditions for parameter checking.
KVarCondition = {
	NotNull = function(val)
		return {val ~= nil, "object"}
	end,

	Number = function(val)
		return {isnumber(val), "number"}
	end,

	NumberGreater = function(val,compare)
		return {isnumber(val) and val > compare, s_format("number > %d",compare)}
	end,

	NumberLess = function(val,compare)
		return {isnumber(val) and val < compare, s_format("number < %d",compare)}
	end,

	NumberGreaterOrEqual = function(val,compare)
		return {isnumber(val) and val >= compare, s_format("number >= %d",compare)}
	end,

	NumberLessOrEqual = function(val,compare)
		return {isnumber(val) and val <= compare, s_format("number <= %d",compare)}
	end,

	NumberInRange = function(val,min,max)
		return {isnumber(val) and val >= min and val <= max, s_format("%d <= number <= %d",min,max)}
	end,

	String = function(val)
		return {isstring(val), "string"}
	end,

	StringNotEmpty = function(val)
		return {isstring(val), "string (len > 0)"}
	end,

	Table = function(val)
		return {istable(val), "table"}
	end,

	TableSequential = function(val)
		return {istable(val) and table.IsSequential(val), "sequential table"}
	end,

	TableMeta = function(val,compare,typeName)
		return {istable(val) and getmetatable(val).__index == compare, typeName}
	end,

	Bool = function(val)
		return {isbool(val), "bool"}
	end,

	Function = function(val)
		return {isfunction(val), "function"}
	end,

	Entity = function(val)
		return {isentity(val) and IsValid(val), "valid entity"}
	end,

	Player = function(val)
		return {isentity(val) and IsValid(val) and val:IsPlayer(), "valid player"}
	end,

	Color = function(val)
		return {IsColor(val), "color"}
	end,

	Vector = function(val)
		return {isvector(val), "Vector"}
	end,

	Angle = function(val)
		return {isangle(val), "Angle"}
	end,
}

---SHARED,STATIC<br>
---Validate function argument.
---@param index number
---@param name string
---@param assertion [boolean, string]
function KError.ValidateArg(index,name,assertion)
	if assertion[1] then return end
	error(s_format("arg #%i, [%s]: expected [%s].",index,name,assertion[2]))
end

---SHARED,STATIC<br>
---Validate function table argument values.
---@param index number
---@param name string
---@param keyAssertion [boolean, string]
---@param valueAssertion [boolean, string]
function KError.ValidateKVArg(index,name,keyAssertion,valueAssertion)
	if keyAssertion[1] and keyAssertion[1] then return end
	error(s_format("arg #%i, [%s]: expected key [%s], expected value [%s].",index,name,keyAssertion[2],valueAssertion[2]))
end