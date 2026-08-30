local VERTEX_MAX_DECIMALS = 4

local m_Round = math.Round

---@class _KMeshDataInternal
local internal = {}

local function flipVector(staticProp,v)
    if staticProp then return v end
    v.x,v.y,v.z = -v.y,v.x,v.z
    return v
end

---@param vec Vector
function internal.RoundVector(vec)
    vec.x = m_Round(vec.x,VERTEX_MAX_DECIMALS)
    vec.y = m_Round(vec.y,VERTEX_MAX_DECIMALS)
    vec.z = m_Round(vec.z,VERTEX_MAX_DECIMALS)
    return vec
end

---@param modelPath string
function internal.ModelExists(modelPath)
    if string.find(modelPath,"models/",1,true) ~= 1 then return false end
    return file.Exists(modelPath,"GAME")
end

---@param modelPath string
---@return {[string]: MeshVertex[]}
function internal.GetCorrectedModelMeshes(modelPath)
    local meshVertexesByMaterial = {}
    local modelMeshes,_ = util.GetModelMeshes(modelPath)
    local modelData = util.GetModelInfo(modelPath)
    local staticProp = modelData.StaticProp

    for _,modelMeshData in pairs(modelMeshes) do
        local material = modelMeshData.material
        local meshVertexes = {}
        meshVertexesByMaterial[material] = meshVertexes

        for _,meshVertex in pairs(modelMeshData.triangles) do
            local pos = Vector(meshVertex.pos)
            local normal = Vector(meshVertex.normal)
            local binormal = Vector(meshVertex.binormal)
            local tangent = Vector(meshVertex.tangent)

            table.insert(meshVertexes,{
                pos = flipVector(staticProp,pos),
                normal = flipVector(staticProp,normal),
                binormal = binormal and flipVector(staticProp,binormal),
                tangent = tangent and flipVector(staticProp,tangent),
                userdata = meshVertex.userdata,
                u = meshVertex.u,
                v = meshVertex.v,
                weights = meshVertex.weights,
            })
        end
    end

    return meshVertexesByMaterial
end

return internal