if KHalo then return end

---CLIENT, STATIC<br/>
---HaloEx library refactor.
KHalo = {}

local c_Start3D = cam.Start3D
local c_End3D = cam.End3D
local c_IgnoreZ = cam.IgnoreZ
local r_Clear = render.Clear
local r_DrawScreenQuad = render.DrawScreenQuad
local r_DrawScreenQuadEx = render.DrawScreenQuadEx
local r_SetMaterial = render.SetMaterial
local r_SetBlend = render.SetBlend
local r_MaterialOverride = render.MaterialOverride
local r_SetColorModulation = render.SetColorModulation
local r_OverrideDepthEnable = render.OverrideDepthEnable
local r_GetRenderTarget = render.GetRenderTarget
local r_SetRenderTarget = render.SetRenderTarget
local r_CopyRenderTargetToTexture = render.CopyRenderTargetToTexture
local r_BlurRenderTarget = render.BlurRenderTarget
local r_SetStencilEnable = render.SetStencilEnable
local r_SetStencilFailOperation = render.SetStencilFailOperation
local r_SetStencilZFailOperation = render.SetStencilZFailOperation
local r_SetStencilPassOperation = render.SetStencilPassOperation
local r_SetStencilCompareFunction = render.SetStencilCompareFunction
local r_SetStencilWriteMask = render.SetStencilWriteMask
local r_SetStencilReferenceValue = render.SetStencilReferenceValue
local r_SetStencilTestMask = render.SetStencilTestMask
local math_cos = math.cos
local math_sin = math.sin
local math_Clamp = math.Clamp
local ent_meta = FindMetaTable("Entity")
local e_DrawModel = ent_meta.DrawModel
local mat_meta = FindMetaTable("IMaterial")
local mat_SetTexture = mat_meta.SetTexture
local EyePos = EyePos
local EyeAngles = EyeAngles
local ScrW = ScrW
local ScrH = ScrH
local pairs = pairs
local next = next

local pi = math.pi
local STENCILOPERATION_KEEP = STENCILOPERATION_KEEP
local STENCILOPERATION_REPLACE = STENCILOPERATION_REPLACE
local STENCILCOMPARISONFUNCTION_ALWAYS = STENCILCOMPARISONFUNCTION_ALWAYS
local STENCILCOMPARISONFUNCTION_NOTEQUAL = STENCILCOMPARISONFUNCTION_NOTEQUAL

local mat_Color
local mat_Copy
local mat_Add
local mat_Sub
local rt_Stencil
local rt_Store
local drawHaloHook

hook.Add("PreRender","KHalo",function()
	mat_Color = Material("model_color")
	mat_Copy = Material("pp/copy")
	mat_Add	= Material("pp/add")
	mat_Sub	= Material("pp/sub")
	rt_Stencil = GetRenderTarget("halo_ex_stencil" .. os.clock(), ScrW() / 8, ScrH() / 8)
	rt_Store = GetRenderTarget("halo_ex_store" .. os.clock(), ScrW(), ScrH())
	hook.Remove("PreRender","KHalo")
end)

local halos = {}

---CLIENT<br/>
---Register a KHalo to the render stack.<br/>
---
---params:
--- - sequential Entity[] Ents
--- - Color Color
--- - bool? Hidden = false
--- - bool? Additive = false
--- - bool? IgnoreZ = false
--- - number? BlurX = 2 [0..]
--- - number? BlurY = 2 [0..]
--- - number? SphericalSize = 1 [0..]
--- - number? Shape = 1 [0..]
--- - number? DrawPasses = 1 [0,32]
--- - number? Amount = 1 [0,32]
---@param key any
---@param params table
function KHalo.Add(key,params)
	KError.ValidateArg("key",KVarConditions.NotNull(key))
	KError.ValidateArg("params",KVarConditions.Table(params))

	KError.ValidateArg("params.Ents",KVarConditions.Table(params.Ents))
	local entLookup = {}
	for k,v in pairs(params.Ents) do
		KError.ValidateArg("params.Ents." .. k,KVarConditions.Entity(v))
		entLookup[v] = true
	end
	params.Ents = entLookup

	KError.ValidateArg("params.Color",KVarConditions.Color(params.Color))

	if params.Hidden == nil then params.Hidden = false end
	KError.ValidateArg("params.Hidden",KVarConditions.Bool(params.Hidden))

	if params.BlurX == nil then params.BlurX = 2 end
	KError.ValidateArg("params.BlurX",KVarConditions.NumberGreaterOrEqual(params.BlurX,0))

	if params.BlurY == nil then params.BlurY = 2 end
	KError.ValidateArg("params.BlurY",KVarConditions.NumberGreaterOrEqual(params.BlurY,0))

	if params.DrawPasses == nil then params.DrawPasses = 1 end
	KError.ValidateArg("params.DrawPasses",KVarConditions.NumberInRange(params.DrawPasses,1,32))

	if params.Additive == nil then params.Additive = true end
	KError.ValidateArg("params.Additive",KVarConditions.Bool(params.Additive))

	if params.IgnoreZ == nil then params.IgnoreZ = false end
	KError.ValidateArg("params.IgnoreZ",KVarConditions.Bool(params.IgnoreZ))

	if params.Amount == nil then params.Amount = 1 end
	KError.ValidateArg("params.Amount",KVarConditions.NumberInRange(params.Amount,0,32))

	if params.SphericalSize == nil then params.SphericalSize = 1 end
	KError.ValidateArg("params.SphericalSize",KVarConditions.NumberGreaterOrEqual(params.SphericalSize,0))

	if params.Shape == nil then params.Shape = 1 end
	KError.ValidateArg("params.Shape",KVarConditions.NumberGreaterOrEqual(params.Shape,1))

	halos[key] = params
	hook.Add("PostDrawEffects","RenderKHalos",drawHaloHook)
end

---CLIENT<br/>
---Unregister a KHalo from the render stack.
function KHalo.Remove(key)
	halos[key] = nil
end

---CLIENT<br/>
---Add a entity to a registered KHalo.
---@param ent Entity
function KHalo.AddEnt(key,ent)
	KError.ValidateArg("key",KVarConditions.NotNull(key))
	local tab = halos[key]
	if not tab then return end

	KError.ValidateArg("ent",KVarConditions.Entity(ent))
	tab.Ents[ent] = true
end

---CLIENT<br/>
---Remove a entity from a registered KHalo.
---@param ent Entity
function KHalo.RemoveEnt(key,ent)
	KError.ValidateArg("key",KVarConditions.NotNull(key))
	local tab = halos[key]
	if not tab then return end

	tab.Ents[ent] = nil
end

local function renderHalos(haloTab)
	local ents = haloTab.Ents
	local additive = haloTab.Additive
	local ignoreZ = haloTab.IgnoreZ

	if not next(ents) then return end

	local OldRT = r_GetRenderTarget()

	do -- SETUP
		-- Copy what's currently on the screen to another texture
		r_CopyRenderTargetToTexture(rt_Store)

		-- Clear the colour and the stencils, not the depth
		if additive then
			r_Clear(0,0,0,255,false,true)
		else
			r_Clear(255,255,255,255,false,true)
		end
	end

	do -- FILL STENCIL
		c_Start3D(EyePos(),EyeAngles())
		c_IgnoreZ(ignoreZ)
		r_OverrideDepthEnable(true,false)

		r_SetStencilEnable(true)
		r_SetStencilFailOperation(STENCILOPERATION_KEEP)
		r_SetStencilZFailOperation(STENCILOPERATION_KEEP)
		r_SetStencilPassOperation(STENCILOPERATION_REPLACE)
		r_SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_ALWAYS)
		r_SetStencilWriteMask(1)
		r_SetStencilReferenceValue(1)

		r_SetBlend(0)

		for e,_ in pairs(ents) do
			if not IsValid(e) then
				ents[e] = nil
				continue
			end

			e_DrawModel(e)
		end
		c_End3D()
	end

	do -- FILL COLOUR
		c_Start3D(EyePos(),EyeAngles())
		r_MaterialOverride(mat_Color)
		c_IgnoreZ(ignoreZ)

		r_SetStencilEnable(true)
		r_SetStencilWriteMask(0)
		r_SetStencilReferenceValue(0)
		r_SetStencilTestMask(1)
		r_SetStencilFailOperation(STENCILOPERATION_KEEP)
		r_SetStencilPassOperation(STENCILOPERATION_KEEP)
		r_SetStencilZFailOperation(STENCILOPERATION_KEEP)
		r_SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_NOTEQUAL)

		local c = haloTab.Color
		local r = c.r / 255
		local g = c.g / 255
		local b = c.b / 255
		local a = c.a / 255
		for e,_ in pairs(ents) do
			r_SetColorModulation(r,g,b)
			r_SetBlend(a)
			e_DrawModel(e)
		end

		r_MaterialOverride( nil )
		r_SetStencilEnable( false )
		c_End3D()
	end

	do -- BLUR IT
		r_CopyRenderTargetToTexture(rt_Stencil)
		r_OverrideDepthEnable(false,false)
		r_SetStencilEnable(false)
		r_BlurRenderTarget(rt_Stencil,haloTab.BlurX,haloTab.BlurY,haloTab.Amount)

		-- Put our scene back
		r_SetRenderTarget(OldRT )
		r_SetColorModulation(1,1,1)
		r_SetStencilEnable(false)
		r_OverrideDepthEnable(true,false)
		r_SetBlend(1)
		mat_SetTexture(mat_Copy,"$basetexture",rt_Store)
		r_SetMaterial(mat_Copy)
		r_DrawScreenQuad()
	end

	do -- DRAW IT TO THE SCEEN
		r_SetStencilEnable(true)
		r_SetStencilWriteMask(0)
		r_SetStencilReferenceValue(0)
		r_SetStencilTestMask(1)
		r_SetStencilFailOperation(STENCILOPERATION_KEEP)
		r_SetStencilPassOperation(STENCILOPERATION_KEEP)
		r_SetStencilZFailOperation(STENCILOPERATION_KEEP)
		r_SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_EQUAL)

		if additive then
			mat_SetTexture(mat_Add,"$basetexture",rt_Stencil)
			r_SetMaterial(mat_Add)
		else
			mat_SetTexture(mat_Sub,"$basetexture",rt_Stencil)
			r_SetMaterial(mat_Sub)
		end

		local dp = haloTab.DrawPasses
		local sphericalSize = haloTab.SphericalSize
		local clampRange = sphericalSize * haloTab.Shape
		for i = 0,dp do
			local n = i / dp
			local x = math_sin(n * pi * 2) * sphericalSize
			local y = math_cos(n * pi * 2) * sphericalSize
			r_DrawScreenQuadEx(
				math_Clamp(x,-clampRange,clampRange),
				math_Clamp(y,-clampRange,clampRange),
				ScrW(),
				ScrH()
			)
		end
	end

	do -- PUT EVERYTHING BACK HOW WE FOUND IT
		r_SetStencilWriteMask(0)
		r_SetStencilReferenceValue(0)
		r_SetStencilTestMask(0)
		r_SetStencilEnable(false)
		r_OverrideDepthEnable(false,false)
		r_SetBlend(1)
	end

	c_IgnoreZ(false)
end

function drawHaloHook()
	if not next(halos) then
		hook.Remove("PostDrawEffects","RenderKHalos")
		return
	end

	for _,v in pairs(halos) do
		renderHalos(v)
	end
end