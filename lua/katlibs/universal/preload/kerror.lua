
local ASSERTION_VALUE = 1
local ASSERTION_RESULT = 2
local ASSERTION_EXPECTATION = 3

---SHARED,STATIC<br/>
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

local kc_Is
hook.Add("KatLibsLoaded","KError",function()
	kc_Is = KClass.Is
end)

---SHARED,STATIC<br/>
---Conditions for parameter checking.
KVarConditions = {
	---@return [any, boolean, string]
	NotNull = function(val)
		return {val, val ~= nil, "object"}
	end,

	---@return [number, boolean, string]
	Number = function(val)
		return {val, isnumber(val), "number"}
	end,

	---@return [number, boolean, string]
	NumberGreater = function(val,compare)
		return {val, isnumber(val) and val > compare, s_format("number > %d",compare)}
	end,

	---@return [number, boolean, string]
	NumberLess = function(val,compare)
		return {val, isnumber(val) and val < compare, s_format("number < %d",compare)}
	end,

	---@return [number, boolean, string]
	NumberGreaterOrEqual = function(val,compare)
		return {val, isnumber(val) and val >= compare, s_format("number >= %d",compare)}
	end,

	---@return [number, boolean, string]
	NumberLessOrEqual = function(val,compare)
		return {val, isnumber(val) and val <= compare, s_format("number <= %d",compare)}
	end,

	---@return [number, boolean, string]
	NumberInRange = function(val,min,max)
		return {val, isnumber(val) and val >= min and val <= max, s_format("%d <= number <= %d",min,max)}
	end,

	---@return [string, boolean, string]
	String = function(val)
		return {val, isstring(val), "string"}
	end,

	---@return [string, boolean, string]
	StringNotEmpty = function(val)
		return {val, isstring(val), "string (len > 0)"}
	end,

	---@return [table, boolean, string]
	Table = function(val)
		return {val, istable(val), "table"}
	end,

	---@return [table, boolean, string]
	TableSequential = function(val)
		return {val, istable(val) and table.IsSequential(val), "sequential table"}
	end,

	---@return [table, boolean, string]
	TableMeta = function(val,compare,typeName)
		return {val, istable(val) and getmetatable(val).__index == compare, typeName}
	end,

	---@return [boolean, boolean, string]
	Bool = function(val)
		return {val, isbool(val), "bool"}
	end,

	---@return [function, boolean, string]
	Function = function(val)
		return {val, isfunction(val), "function"}
	end,

	---@return [Entity, boolean, string]
	Entity = function(val)
		return {val, isentity(val) and IsValid(val), "valid entity"}
	end,

	---@return [Player, boolean, string]
	Player = function(val)
		return {val, isentity(val) and IsValid(val) and val:IsPlayer(), "valid player"}
	end,

	---@return [Color, boolean, string]
	Color = function(val)
		return {val, IsColor(val), "color"}
	end,

	---@return [Vector, boolean, string]
	Vector = function(val)
		return {val, isvector(val), "Vector"}
	end,

	---@return [Angle, boolean, string]
	Angle = function(val)
		return {val, isangle(val), "Angle"}
	end,

	---@return [KClass, boolean, string]
	KClass = function(val,compare,typeName)
		if compare == nil then return {val, kc_Is(val), "KClass"} end
		return {val, kc_Is(val,compare), typeName}
	end,
}

---SHARED,STATIC<br/>
---Validate function argument.
---@generic T
---@param name string
---@param assertion [T, boolean, string]
---@return T value The value passed, if valid.
function KError.ValidateArg(name,assertion)
	if assertion[ASSERTION_RESULT] then return assertion[ASSERTION_VALUE] end

	error(s_format("arg [%s]: expected [%s].",name,assertion[ASSERTION_EXPECTATION]))
end

---SHARED,STATIC<br/>
---Validate nullable function argument.
---@generic T
---@param name string
---@param assertion [T, boolean, string]
---@return T? value The value passed, if valid.
function KError.ValidateNullableArg(name,assertion)
	if assertion[ASSERTION_VALUE] == nil then return end
	if assertion[ASSERTION_RESULT] then return assertion[ASSERTION_VALUE] end

	error(s_format("arg [%s]: expected [%s].",name,assertion[ASSERTION_EXPECTATION]))
end

---SHARED,STATIC<br/>
---Validate function table argument values.
---@param name string
---@param keyAssertion [any, boolean, string]
---@param valueAssertion [any, boolean, string]
---@return any key The key passed, if valid.
---@return any value The value passed, if valid.
function KError.ValidateKVArg(name,keyAssertion,valueAssertion)
	if keyAssertion[ASSERTION_RESULT] and valueAssertion[ASSERTION_RESULT] then
		return keyAssertion[ASSERTION_VALUE],valueAssertion[ASSERTION_VALUE]
	end

	error(s_format("arg [%s]: expected key [%s], expected value [%s].",name,keyAssertion[ASSERTION_EXPECTATION],valueAssertion[ASSERTION_EXPECTATION]))
end