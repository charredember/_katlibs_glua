local VERTEX_MAX_DECIMALS = 4

---@class VMatrix
local vm_meta = FindMetaTable("VMatrix")
local vm_Identity = vm_meta.Identity
local vm_SetTranslation = vm_meta.SetTranslation
local vm_SetAngles = vm_meta.SetAngles
local vm_Rotate = vm_meta.Rotate
local vm_SetScale = vm_meta.SetScale
---@class Color
local clr_meta = FindMetaTable("Color")
local clr_ToHex = clr_meta.ToHex
---@class IMesh
local im_meta = FindMetaTable("IMesh")
local im_Draw = im_meta.Draw
local im_Destroy = im_meta.Destroy
local v_meta = FindMetaTable("Vector")
local v_Dot = v_meta.Dot

local mesh_Begin = mesh.Begin
local mesh_Position = mesh.Position
local mesh_Normal = mesh.Normal
local mesh_TexCoord = mesh.TexCoord
local mesh_TangentS = mesh.TangentS
local mesh_TangentT = mesh.TangentT
local mesh_UserData = mesh.UserData
local mesh_Color = mesh.Color
local mesh_AdvanceVertex = mesh.AdvanceVertex
local mesh_End = mesh.End
local m_ceil = math.ceil
local util_IntersectRayWithPlane = util.IntersectRayWithPlane
local t_insert = table.insert
local m_Round = math.Round
local isstring = isstring
local util_SHA256 = util.SHA256
local r_SetMaterial = render.SetMaterial
local r_SetBlend = render.SetBlend
local r_SetColorModulation = render.SetColorModulation
local STUDIO_RENDER = STUDIO_RENDER
local STUDIO_DRAWTRANSLUCENTSUBMODELS = STUDIO_DRAWTRANSLUCENTSUBMODELS

local kmd_GetPos,kmd_GetAngles,kmd_GetScale,kmd_GetModel,kmd_GetColor,kmd_GetMaterial,kmd_GetRenderGroup,kmd_GetRenderMode--,kmd_GetClips
hook.Add("KatLibsLoaded","KScene",function()
	kmd_GetPos = KModelData.GetPos
	kmd_GetAngles = KModelData.GetAngles
	kmd_GetScale = KModelData.GetScale
	kmd_GetModel = KModelData.GetModel
	kmd_GetColor = KModelData.GetColor
	kmd_GetMaterial = KModelData.GetMaterial
	kmd_GetRenderGroup = KModelData.GetRenderGroup
	kmd_GetRenderMode = KModelData.GetRenderMode
	kmd_GetClips = KModelData.GetClips
end)

local splitMesh
do --mesh clipping
	local function isOnSideA(meshVertex,planeOrigin,planeNormal)
		local vector = meshVertex.pos
		local toPointFromPlane = vector - planeOrigin
		return v_Dot(toPointFromPlane,planeNormal) < 0
	end

	local function splitTriangle(splitPoint,splitBase,meshVertexPoint,meshVertexBase1,meshVertexBase2,planeOrigin,planeNormal)
		--[[
				  	      /\ point					planeNormal	^
					     /  \									|
		--intersection1-o----o-intersection2--------planeOrigin-o--
				  base1/______\ base2
		]]
		local vectorPoint,normalPoint,binormalPoint,tangentPoint,uPoint,vPoint = meshVertexPoint.pos,meshVertexPoint.normal,meshVertexPoint.binormal,meshVertexPoint.tangent,meshVertexPoint.u,meshVertexPoint.v
		local vectorBase1,uBase1,vBase1 = meshVertexBase1.pos,meshVertexBase1.u,meshVertexBase1.v
		local vectorBase2,uBase2,vBase2 = meshVertexBase2.pos,meshVertexBase2.u,meshVertexBase2.v
		local vectorIntersection1 = util_IntersectRayWithPlane(vectorPoint,vectorBase1 - vectorPoint,planeOrigin,planeNormal)
		local vectorIntersection2 = util_IntersectRayWithPlane(vectorPoint,vectorBase2 - vectorPoint,planeOrigin,planeNormal)
		local uIntersection1,vIntersection1 = (uPoint + uBase1) / 2, (vPoint + vBase1) / 2
		local uIntersection2,vIntersection2 = (uPoint + uBase2) / 2, (vPoint + vBase2) / 2

		local meshVertexIntersection1 = { pos = vectorIntersection1, normal = normalPoint, binormal = binormalPoint, tangent = tangentPoint, u = uIntersection1, v = vIntersection1 }
		local meshVertexIntersection2 = { pos = vectorIntersection2, normal = normalPoint, binormal = binormalPoint, tangent = tangentPoint, u = uIntersection2, v = vIntersection2 }

		--add point triangle
		t_insert(splitPoint,meshVertexPoint)
		t_insert(splitPoint,meshVertexIntersection1)
		t_insert(splitPoint,meshVertexIntersection2)

		--split base into two triangles
		t_insert(splitBase,meshVertexIntersection1)
		t_insert(splitBase,meshVertexBase1)
		t_insert(splitBase,meshVertexBase2)

		t_insert(splitBase,meshVertexBase2)
		t_insert(splitBase,meshVertexIntersection2)
		t_insert(splitBase,meshVertexIntersection1)
	end

	local function sortTriangleToSide(splitA,splitB,meshVertex1,meshVertex2,meshVertex3,planeOrigin,planeNormal)
		local IsV1OnSideA = isOnSideA(meshVertex1,planeOrigin,planeNormal)
		local IsV2OnSideA = isOnSideA(meshVertex2,planeOrigin,planeNormal)
		local IsV3OnSideA = isOnSideA(meshVertex3,planeOrigin,planeNormal)

		if IsV1OnSideA and IsV2OnSideA and IsV3OnSideA then --111
			t_insert(splitA,meshVertex1)
			t_insert(splitA,meshVertex2)
			t_insert(splitA,meshVertex3)
			return
		end

		if not IsV1OnSideA and not IsV2OnSideA and not IsV3OnSideA then
			t_insert(splitB,meshVertex1)
			t_insert(splitB,meshVertex2)
			t_insert(splitB,meshVertex3)
			return
		end

		--find which one is the "point"
		--it is imperative that the vertices retain the same order
		if IsV1OnSideA ~= IsV2OnSideA and IsV1OnSideA ~= IsV3OnSideA then
			local splitPoint = IsV1OnSideA and splitA or splitB
			local splitBase = IsV1OnSideA and splitB or splitA
			splitTriangle(splitPoint,splitBase,meshVertex1,meshVertex2,meshVertex3,planeOrigin,planeNormal)
			return
		end

		if IsV2OnSideA ~= IsV1OnSideA and IsV2OnSideA ~= IsV3OnSideA then
			local splitPoint = IsV2OnSideA and splitA or splitB
			local splitBase = IsV2OnSideA and splitB or splitA
			splitTriangle(splitPoint,splitBase,meshVertex2,meshVertex3,meshVertex1,planeOrigin,planeNormal)
			return
		end

		if IsV3OnSideA ~= IsV1OnSideA and IsV3OnSideA ~= IsV2OnSideA then
			local splitPoint = IsV3OnSideA and splitA or splitB
			local splitBase = IsV3OnSideA and splitB or splitA
			splitTriangle(splitPoint,splitBase,meshVertex3,meshVertex1,meshVertex2,planeOrigin,planeNormal)
			return
		end
	end

	function splitMesh(meshVertexTab,planeOrigin,planeNormal)
		local splitA = {}
		local splitB = {}

		assert(#meshVertexTab % 3,"meshVertexTab not a multiple of 3!")
		local triCount = #meshVertexTab / 3

		for i = 0,triCount - 1 do
			local offset = i * 3
			sortTriangleToSide(splitA,splitB,
				meshVertexTab[offset + 1],meshVertexTab[offset + 2],meshVertexTab[offset + 3],
				planeOrigin,planeNormal
			)
		end

		return splitA, splitB
	end
end

local splitByVisualProperties
do --convert KModelData into MeshVertexes
	--https://wiki.facepunch.com/gmod/Structures/MeshVertex

	local function modelExists(path)
		if string.find(path,"models/",1,true) ~= 1 then return false end
		return file.Exists(path,"GAME")
	end

	local function roundVector(vec)
		vec.x = m_Round(vec.x,VERTEX_MAX_DECIMALS)
		vec.y = m_Round(vec.y,VERTEX_MAX_DECIMALS)
		vec.z = m_Round(vec.z,VERTEX_MAX_DECIMALS)
		return vec
	end

	local normalMatrix = Matrix()
	local modelMatrix = Matrix()
	local ANG_FIX = Angle(0,90,0)

	local function appendModelTriangleData(triangles,modelData)
		vm_Identity(normalMatrix)
		vm_SetAngles(normalMatrix,kmd_GetAngles(modelData))
		vm_Rotate(modelMatrix,ANG_FIX)

		modelMatrix:Set(normalMatrix)
		vm_SetTranslation(modelMatrix,kmd_GetPos(modelData))
		vm_SetScale(modelMatrix,kmd_GetScale(modelData))

		local modelPath = kmd_GetModel(modelData)
		if not modelExists(modelPath) then
			return
		end

		local modelTriangles = util.GetModelMeshes(modelPath)[1].triangles

		for _,clip in pairs(kmd_GetClips(modelData)) do
			_,modelTriangles = splitMesh(modelTriangles,clip.Pos,clip.Normal)
		end

		for _,meshVertex in pairs(modelTriangles) do
			local normal = roundVector(normalMatrix * meshVertex.normal)
			local binormal = meshVertex.binormal and roundVector(normalMatrix * meshVertex.binormal)
			local tangent = meshVertex.tangent and roundVector(normalMatrix * meshVertex.tangent)
			local pos = roundVector(modelMatrix * meshVertex.pos)

			t_insert(triangles,{
				pos = pos,
				normal = normal,
				binormal = binormal,
				tangent = tangent,
				userdata = meshVertex.userdata,
				u = meshVertex.u,
				v = meshVertex.v,
			})
		end
	end

	function splitByVisualProperties(kModelDataTable)
		local meshData = {}

		for i = 1,#kModelDataTable do
			local currModelData = kModelDataTable[i]
			local material = kmd_GetMaterial(currModelData)
			local color = kmd_GetColor(currModelData)
			local renderGroup = kmd_GetRenderGroup(currModelData)
			local renderMode = kmd_GetRenderMode(currModelData)

			local visualPropertyKey = util_SHA256(
				material
				.. clr_ToHex(color,true)
				.. (renderGroup or "")
				.. (renderMode or ""))

			local visualPropertyGroup = meshData[visualPropertyKey]
			if not visualPropertyGroup then
				visualPropertyGroup = {
					TriangleData = {},
					Color = color,
					Material = material,
					RenderGroup = renderGroup,
					RenderMode = renderMode,
				}
				meshData[visualPropertyKey] = visualPropertyGroup
			end

			appendModelTriangleData(visualPropertyGroup.TriangleData,currModelData)
		end

		return meshData
	end
end

local getPriv
---SHARED<br>
---A container object for IMeshes created from KModelData.
---@class KScene
---@overload fun(kModelDataTable: KModelData[]): KScene
KScene,getPriv = KClass(function(kModelDataTable)
	return {
		MeshData = splitByVisualProperties(kModelDataTable),
		Meshes = {},
		RenderOpaque = {},
		RenderBoth = {},
		RenderTransluscent = {},
	}
end)

local function splitSequentialTableByCount(tableToSplit,desiredCount)
	if #tableToSplit < desiredCount then return {tableToSplit} end
	local result = {}
	local currCount = #tableToSplit
	local tablesNeeded = m_ceil(currCount / desiredCount)

	local itr = 0

	for resultIndex = 1,tablesNeeded do
		local subTable = {}

		for newSubIndex = 1, desiredCount do
			itr = itr + 1
			local val = tableToSplit[itr]
			if val == nil then break end
			subTable[newSubIndex] = val
		end

		result[resultIndex] = subTable
	end

	return result
end

function KScene:Destroy()
	local priv = getPriv(self)

	local meshes = priv.Meshes
	for i = 1,#meshes do
		im_Destroy(meshes[i])
	end

	priv.Meshes = {}
	priv.RenderOpaque = {}
	priv.RenderBoth = {}
	priv.RenderTransluscent = {}
end
local ksc_Destroy = KScene.Destroy

if not ktestent2 then
	local new = ents.CreateClientside("base_anim")
	new:SetModel("models/hunter/plates/plate.mdl")
	new:DrawShadow(false)
	--infoEnt.Draw = drawModel
	new.GetRenderMesh = function(self) return self.meshTab end
	new:Spawn()
	new:Activate()

	ktestent2 = new
end

local function buildRenderFunction(newMesh,material,colorRed,colorGreen,colorBlue,colorAlpha)
	local meshTab = {newMesh,material,Entity(366):GetWorldTransformMatrix()}

	return function()
		r_SetMaterial(material)
		r_SetColorModulation(colorRed,colorGreen,colorBlue)
		r_SetBlend(colorAlpha)

		ktestent2.meshTab = meshTab
		ktestent2:SetupBones()
		ktestent2:DrawModel()
		--im_Draw(newMesh)
	end
end

local MAX_TRIS_PER_MESH = 65535
function KScene:Compile()
	ksc_Destroy(self)
	local priv = getPriv(self)

	local meshes = priv.Meshes
	local renderOpaque = priv.RenderOpaque
	local renderBoth = priv.RenderBoth
	local renderTransluscent = priv.RenderTransluscent

	for _,visualPropertyGroup in pairs(priv.MeshData) do
		local material = Material(visualPropertyGroup.Material)
		local color = visualPropertyGroup.Color
		local colorRed = color.r / 255
		local colorGreen = color.g / 255
		local colorBlue = color.b / 255
		local colorAlpha = color.a / 255

		local renderGroup = visualPropertyGroup.RenderGroup
		local destination =
			(renderGroup == RENDERGROUP_TRANSLUCENT) and renderTransluscent or
			(renderGroup == RENDERGROUP_OPAQUE) and renderOpaque or
			renderBoth

		for _,triangleData in pairs(splitSequentialTableByCount(visualPropertyGroup.TriangleData,MAX_TRIS_PER_MESH)) do
			local newMesh = Mesh()
			mesh_Begin(newMesh,MATERIAL_TRIANGLES,#triangleData)
			for i = 1, #triangleData do
				local meshVertex = triangleData[i]

				mesh_Position(meshVertex.pos)
				mesh_Normal(meshVertex.normal)
				mesh_TexCoord(0,meshVertex.u,meshVertex.v)

				local binormal = meshVertex.binormal
				if binormal then mesh_TangentS(binormal) end

				local tangent = meshVertex.tangent
				if tangent then mesh_TangentT(tangent) end

				local userdata = meshVertex.userdata
				if userdata then mesh_UserData(userdata[1],userdata[2],userdata[3],userdata[4]) end

				mesh_Color(255,255,255,255)

				mesh_AdvanceVertex()
			end
			mesh_End()

			t_insert(meshes,newMesh)
			t_insert(destination,buildRenderFunction(newMesh,material,colorRed,colorGreen,colorBlue,colorAlpha))
		end
	end
end

---@param flags STUDIO?
function KScene:Draw(flags)
	if flags == STUDIO_DRAWTRANSLUCENTSUBMODELS then return end

	local renderOpaque = getPriv(self).RenderOpaque
	for i = 1,#renderOpaque do
		renderOpaque[i]()
	end
end
local ksc_Draw = KScene.Draw

---@param flags STUDIO?
function KScene:DrawTranslucent(flags)
	ksc_Draw(self,flags)
	if flags == STUDIO_RENDER then return end

	local priv = getPriv(self)

	local renderBoth = priv.RenderBoth
	for i = 1,#renderBoth do
		renderBoth[i]()
	end

	local renderTransluscent = priv.RenderTransluscent
	for i = 1,#renderTransluscent do
		renderTransluscent[i]()
	end
end

function KScene:IsValid() return #getPriv(self).Meshes > 0 end

local visualPropertyGroupSanitizer = KTableSanitizer({
	Color = {
		r = "number",
		g = "number",
		b = "number",
		a = "number",
	},
	Material = "string",
	RenderGroup = "number",
	RenderMode = "number",
	TriangleData = "TriangleData[]",
},{
	TriangleData = {
		color = {
			r = "number",
			g = "number",
			b = "number",
			a = "number",
		},
		normal = "Vector",
		tangent = "Vector",
		binomial = "Vector",
		pos = "Vector",
		u = "number?",
		v = "number?",
	}
})

local jsonConstructor = getPriv(KScene).GetFactory(function(priv)
	return priv
end)

---SHARED<br>
---Gets a JSON-serializable table representing this object that can be used to recreate this object later.
---@return table
function KScene:GetSerializable()
	local priv = getPriv(self)
	---@cast priv table

	local copy = table.Copy(priv)
	copy.Meshes = nil
	copy.RenderOpaque = nil
	copy.RenderBoth = nil
	copy.RenderTransluscent = nil
	return copy
end

---SHARED,STATIC<br>
---Creates a new object populated with values from a table generated by GetSerializable().<BR>
---Returns nil if deserialization unsuccessful.
---@param serializable table
---@return KScene?
function KScene.FromSerializable(serializable)
	local sanitized = {}

	for key,visualPropertyGroup in pairs(serializable) do
		if not isstring(key) then return end
		local sanitizedGroup = visualPropertyGroupSanitizer(visualPropertyGroup)
		if not sanitizedGroup then return end
		sanitized[key] = sanitizedGroup
	end

	return jsonConstructor(sanitized)
end

hook.Run("KatLibsLoaded")