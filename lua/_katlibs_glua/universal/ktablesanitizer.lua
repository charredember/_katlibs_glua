local istable = istable
local s_format = string.format
local s_EndsWith = string.EndsWith
local s_Replace = string.Replace
local t_insert = table.insert
local t_concat = table.concat


local GENERATED_CODE_TEMPLATE = [[
local istable = istable
local type = type
local err
local function getError() return err end

%s

return eval_main,getError
]]

local EVALUATION_FUNCTION_TEMPLATE = [[

local function %s(check,sanitized)
	local key,val,san,sanArr,typ
%s
	return true
end
]]

local EVALUATE_BASE = [[

	--------------------
	key = "%s"
	val = check[key]
%s
	sanitized[key] = san
]]

local EVALUATE_MODIFIER_NULLABLE = [[
	if val ~= nil then
%s
	end
]]

local EVALUATE_MODIFIER_ARRAY = [[
	if not istable(val) then
		err = key .. " isn't a table!"
		return
	end
	sanArr = {}
	for i = 1, #val do
		local key = i
		local val = val[i]
%s
		sanArr[i] = san
	end
	san = sanArr
]]

local EVALUATE_TYPE = [[
	typ = "%s"
	if type(val) ~= typ then
		err = key .. " isn't a " .. typ
		return
	end
	san = val
]]

local EVALUATE_SUBTABLE = [[
	if not istable(val) then
		err = key .. " isn't a table!"
		return
	end
	san = {}
	if not %s(val,san) then return end
]]

local EVALUATE_MAIN_CALLNAME = "eval_main"
local EVALUATE_SUBTABLE_CALLNAME = "eval_stab_%s%s"
local EVALUATE_CUSTOMTYPE_CALLNAME = "eval_type_%s"

local TO_POINTER = "%p"

local generateTableEvaluationCode
function generateTableEvaluationCode(recursionData)
	local evaluationFunctions = recursionData.EvaluationFunctions
	local traversed = recursionData.Traversed or {}
	local customTypes = recursionData.CustomTypes or {}

	local currentEvaluation = {}
	for k,v in pairs(recursionData.CurrentTable) do
		if istable(v) then
			if traversed[v] then error("infinite recursion detected!") end
			traversed[v] = true

			--add memory address so no duplicates are possible
			local callName = s_format(EVALUATE_SUBTABLE_CALLNAME,k,s_format(TO_POINTER,v))
			t_insert(currentEvaluation,s_format(EVALUATE_BASE,k,s_format(EVALUATE_SUBTABLE,callName)))
			generateTableEvaluationCode({
				CurrentTable = v,
				CallName = callName,
				EvaluationFunctions = evaluationFunctions,
				CustomTypes = {},
				Traversed = traversed,
			})
		elseif isstring(v) then
			if v == "" then continue end

			local evalFunc

			local nullable = s_EndsWith(v,"?")
			if nullable then v = s_Replace(v,"?","") end

			local isArray = s_EndsWith(v,"[]") or s_EndsWith(v,"[]?")
			if isArray then v = s_Replace(v,"[]","") end

			if customTypes[v] then
				evalFunc = s_format(EVALUATE_SUBTABLE,s_format(EVALUATE_CUSTOMTYPE_CALLNAME,v))
			else
				evalFunc = s_format(EVALUATE_TYPE,v)
			end

			if isArray then
				evalFunc = s_format(EVALUATE_MODIFIER_ARRAY,s_Replace(evalFunc,"\n","\n\t"))
			end

			if nullable then
				evalFunc = s_format(EVALUATE_MODIFIER_NULLABLE,s_Replace(evalFunc,"\n","\n\t"))
			end


			t_insert(currentEvaluation,s_format(EVALUATE_BASE,k,s_format(evalFunc,k,type)))
		end
	end

	t_insert(evaluationFunctions,s_format(EVALUATION_FUNCTION_TEMPLATE,recursionData.CallName,t_concat(currentEvaluation)))
end

---SHARED,STATIC<br>
---Allows creation of sanitizer objects for tables. Useful for user input cases.<br>
---**WARNING: Calls CompileString internally during initialization.**
---@return KTableSanitizer
---@class KTableSanitizer : function
function KTableSanitizer(tableStructure,customTypeStructures)
	local evaluationFunctions = {}

	for typeName,typeStructure in pairs(customTypeStructures) do
		generateTableEvaluationCode({
			CurrentTable = typeStructure,
			CallName = s_format(EVALUATE_CUSTOMTYPE_CALLNAME,typeName),
			EvaluationFunctions = evaluationFunctions,
		})
	end

	generateTableEvaluationCode({
		CurrentTable = tableStructure,
		CallName = EVALUATE_MAIN_CALLNAME,
		EvaluationFunctions = evaluationFunctions,
		CustomTypes = customTypeStructures,
	})

	local fullCode = s_format(GENERATED_CODE_TEMPLATE,t_concat(evaluationFunctions))
	local performCheck,getError = CompileString(fullCode,"KTableSanitizer")()

	return function(check)
		local sanitized = {}
		if not performCheck(check,sanitized) then return nil,getError() end
		return sanitized
	end
end