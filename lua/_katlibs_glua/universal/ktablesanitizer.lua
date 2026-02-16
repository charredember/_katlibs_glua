local istable = istable
local s_format = string.format
local s_match = string.match
local t_insert = table.insert
local t_concat = table.concat

local EVALUATE_MAIN_CALLNAME = "eval_main"
local EVALUATE_SUBTABLE_CALLNAME = "eval_%s_%s"
local GENERATED_CODE_TEMPLATE = [[
local istable = istable
local type = type
local evaluation,key,value,error
local function getError() return error end

%s

return eval_main,getError
]]

local EVALUATION_FUNCTION_TEMPLATE = [[

local function %s(check,sanitized)
	if not istable(check) then
		error = " %s isn't a table!"
		return
	end
%s
	return true
end
]]

local EVALUATE_TYPE = [[

	key = "%s"
	value = check[key]
	if type(value) != "%s" then
		error = key .. " is the wrong type: " .. type(value)
		return
	end
	sanitized[key] = value
]]

local EVALUATE_NULLABLE_TYPE = [[

	key = "%s"
	value = check[key]
	if value ~= nil then
		if type(value) != "%s" then
		error = key .. " is the wrong type: " .. type(value)
			return
		end
		sanitized[key] = value
	end
]]

local EVALUATE_TABLE = [[

	key = "%s"
	value = {}
	sanitized[key] = value
	evaluation = %s(check[key],value)
	if not evaluation then return end
]]

local TO_POINTER = "%p"

local generateTableEvaluationCode
function generateTableEvaluationCode(recursionData)
	local evaluationFunctions = recursionData.EvaluationFunctions
	local traversed = recursionData.Traversed

	local currentEvaluation = {}
	for k,v in pairs(recursionData.CurrentTable) do
		if istable(v) then
			if traversed[v] then error("infinite recursion detected!") end
			traversed[v] = true

			--add memory address so no duplicates are possible
			local callName = s_format(EVALUATE_SUBTABLE_CALLNAME,k,s_format(TO_POINTER,v))
			t_insert(currentEvaluation,s_format(EVALUATE_TABLE,k,callName))
			generateTableEvaluationCode({
				CurrentTable = v,
				CallName = callName,
				EvaluationFunctions = evaluationFunctions,
				Traversed = traversed,
			})
		else
			local type,isNullable = s_match(v,"^(%a+)(??)$")
			if not type then continue end
			local evalFunc = isNullable == "?" and EVALUATE_NULLABLE_TYPE or EVALUATE_TYPE
			t_insert(currentEvaluation,s_format(evalFunc,k,type))
		end
	end

	t_insert(evaluationFunctions,s_format(EVALUATION_FUNCTION_TEMPLATE,recursionData.CallName,recursionData.CallName,t_concat(currentEvaluation)))
end

--TODO: Add functionality for sequential JSON arrays

---SHARED,STATIC<br>
---Allows creation of sanitizer objects for tables. Useful for user input cases.
---@return KTableSanitizer
---@class KTableSanitizer : function
function KTableSanitizer(tableStructure)
	local evaluationFunctions = {}

	generateTableEvaluationCode({
		CurrentTable = tableStructure,
		CallName = EVALUATE_MAIN_CALLNAME,
		EvaluationFunctions = evaluationFunctions,
		Traversed = {},
	})

	local fullCode = s_format(GENERATED_CODE_TEMPLATE,t_concat(evaluationFunctions))
	local performCheck,getError = CompileString(fullCode,"KTableSanitizer")()

	return function(check)
		local sanitized = {}
		if not performCheck(check,sanitized) then return nil,getError() end
		return sanitized
	end
end