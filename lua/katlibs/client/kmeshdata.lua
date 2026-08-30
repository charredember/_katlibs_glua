---Garry's mod datatype for holding triangle data.<br/>
---https://wiki.facepunch.com/gmod/Structures/MeshVertex
---@class MeshVertex
---@field pos Vector
---@field u number
---@field v number
---@field normal Vector
---@field binormal Vector?
---@field tangent Vector?
---@field color Color?
---@field u1 number?
---@field v1 number?
---@field userdata number[]?
---@field weights BoneWeight[]?

---@class VMatrix
local vm_meta = FindMetaTable("VMatrix")
local vm_Identity = vm_meta.Identity
local vm_SetTranslation = vm_meta.SetTranslation
local vm_SetAngles = vm_meta.SetAngles
local vm_SetScale = vm_meta.SetScale
local vm_Invert = vm_meta.Invert
---@class _KMeshDataInternal
local internal = {}
table.Inherit(internal,include("kmeshdata/meshdatasplit.lua"))
table.Inherit(internal,include("kmeshdata/meshdatastream.lua"))
table.Inherit(internal,include("kmeshdata/studioconverter.lua"))
local roundVector = internal.RoundVector
local modelExists = internal.ModelExists
local getCorrectedModelMeshes = internal.GetCorrectedModelMeshes
local splitMesh = internal.SplitMesh
local writeMesh = internal.WriteMesh
local readMesh = internal.ReadMesh
local t_insert = table.insert

local getOrAddRenderPropertyGroup,addMeshVertexes,addModelMesh

local DEFAULT_RENDER_PROPERTIES
hook.Add("KatLibsLoaded","KMeshUtils",function()
    DEFAULT_RENDER_PROPERTIES = {KRenderProperty.ModelMaterialOverride("models/debug/debugwhite")}
end)

local getPriv
---CLIENT<br/>
---Serializable mesh datatype and mesh utility class.
---@class KMeshData
---@overload fun() : KMeshData
KMeshData,getPriv = KClass(function() end)

do --methods
    ---CLIENT<br/>
    ---Add MeshVertex objects to this KMeshData.
    ---@param meshVertexes MeshVertex[]
    ---@param renderProperties? KRenderProperty[]
    ---@param studioProperties? KStudioProperty
    function KMeshData:AddMeshVertexes(meshVertexes,renderProperties,studioProperties)
        if not renderProperties then renderProperties = DEFAULT_RENDER_PROPERTIES end
        if not studioProperties then studioProperties = KStudioProperty() end
        local priv = getPriv(self)
        addMeshVertexes(priv,meshVertexes,renderProperties,studioProperties)
    end

    ---CLIENT<br/>
    ---Converts KModelData into MeshVertex objects and adds them to this KMeshData.
    ---@param models KModelData[]
    ---@param forceBoneIndex? integer
    function KMeshData:AddModelMeshes(models,forceBoneIndex)
        local priv = getPriv(self)
        for _,modelData in ipairs(models) do
            addModelMesh(priv,modelData,forceBoneIndex)
        end
    end

    ---CLIENT<br/>
    ---Returns an iterator for the MeshVertexes.
    function KMeshData:Iterator()
        local priv = getPriv(self)

        local itr = 0
        local currKey = nil
        local current = nil
        ---@type fun(): itr: integer?, meshVertexes: MeshVertex[]?, renderProperties: KRenderProperty?, studioProperties: KStudioProperty?
        return function()
            itr = itr + 1
            currKey,current = next(priv,currKey)
            if current == nil then return nil,nil,nil,nil end
            return itr,current.MeshVertexes,current.RenderProperties,current.StudioProperties
        end
    end
end

do --static functions
    ---CLIENT, STATIC<br/>
    ---Write KMeshData to a stream.
    ---@param stream KWriteStream
    ---@param meshData KMeshData
	---@param taskToken KTaskToken?
    function KMeshData.WriteToStream(stream,meshData,taskToken)
        local priv = getPriv(meshData)
        local meshCount = table.Count(priv)
        stream:WriteUInt8(meshCount)

        for _,data in pairs(priv) do
            KRenderProperty.WriteToStream(stream,data.RenderProperties)
            KStudioProperty.WriteToStream(stream,data.StudioProperties)
            writeMesh(stream,data.MeshVertexes,taskToken)
        end
    end

    ---CLIENT, STATIC<br/>
    ---Read KMeshData from a stream.
    ---@param stream KReadStream
	---@param taskToken KTaskToken?
    ---@return KMeshData
    function KMeshData.ReadFromStream(stream,taskToken)
		local new = KMeshData()
        local priv = getPriv(new)

        local meshCount = stream:ReadUInt8()
        for _ = 1,meshCount do
            local renderProperties = KRenderProperty.ReadFromStream(stream)
            local studioProperties = KStudioProperty.ReadFromStream(stream)
            local destination = getOrAddRenderPropertyGroup(priv,renderProperties,studioProperties)
            destination.MeshVertexes = readMesh(stream,taskToken)
        end

		return new
    end
end

do --helper functions
    ---@param renderProperties KRenderProperty[]
    ---@param studioProperties KStudioProperty
    function getOrAddRenderPropertyGroup(priv,renderProperties,studioProperties)
        local hash = KRenderProperty.GetUniqueHash(renderProperties) .. tostring(studioProperties)
        local destination = priv[hash]

        if not destination then
            destination = {
                MeshVertexes = {},
                RenderProperties = renderProperties,
                StudioProperties = studioProperties,
            }
            priv[hash] = destination
        end

        return destination
    end

    ---@param meshVertexes MeshVertex[]
    ---@param renderProperties KRenderProperty[]
    ---@param studioProperties KStudioProperty
    function addMeshVertexes(priv,meshVertexes,renderProperties,studioProperties)
        local destination = getOrAddRenderPropertyGroup(priv,renderProperties,studioProperties)
        local mesh = destination.MeshVertexes
        for _,meshVertex in ipairs(meshVertexes) do
            t_insert(mesh,meshVertex)
        end
    end

    local normalMatrix = Matrix()
    local modelMatrix = Matrix()
    local clipMatrix = Matrix()
    ---@param modelData KModelData
    ---@param forceBoneIndex integer
    function addModelMesh(priv,modelData,forceBoneIndex)
        local modelPos = modelData:GetPos()
        local modelAngles = modelData:GetAngles()
        local modelScale = modelData:GetScale()
        local modelPath = modelData:GetModel()
        local modelRenderProperties = modelData:GetRenderProperties()
        local modelStudioProperties = modelData:GetStudioProperties()

        vm_Identity(normalMatrix)
        vm_SetAngles(normalMatrix,modelAngles)

        vm_Identity(modelMatrix)
        vm_SetTranslation(modelMatrix,modelPos)
        vm_SetAngles(modelMatrix,modelAngles)
        vm_SetScale(modelMatrix,modelScale)

        vm_Identity(clipMatrix)
        vm_SetScale(clipMatrix,modelScale)
        vm_Invert(clipMatrix)

        if not modelExists(modelPath) then return end

        local meshVertexesByMaterial = getCorrectedModelMeshes(modelPath)
        for material,meshVertexes in pairs(meshVertexesByMaterial) do
            local renderProperties = {KRenderProperty.ModelMaterialOverride(material)}
            local studioProperties = KStudioProperty.Extrapolate(material,modelData:GetColor().a)
            KRenderProperty.Merge(renderProperties,modelRenderProperties)
            KStudioProperty.Merge(studioProperties,modelStudioProperties)

            for _,clip in pairs(modelData:GetClips()) do
                local clipOrigin = clipMatrix * clip.Pos
                local clipNormal = clip.Normal
                _,meshVertexes = splitMesh(meshVertexes,clipOrigin,clipNormal)
            end

            for _,meshVertex in ipairs(meshVertexes) do
                meshVertex.pos = roundVector(modelMatrix * meshVertex.pos)
                meshVertex.normal = roundVector(normalMatrix * meshVertex.normal)
                meshVertex.binormal = meshVertex.binormal and roundVector(normalMatrix * meshVertex.binormal)
                meshVertex.tangent = meshVertex.tangent and roundVector(normalMatrix * meshVertex.tangent)
                --TODO: Support the model's native bone in the future.
                meshVertex.weights = forceBoneIndex and {{bone = forceBoneIndex, weight = 1}}
            end

            addMeshVertexes(priv,meshVertexes,renderProperties,studioProperties)
        end
    end
end
