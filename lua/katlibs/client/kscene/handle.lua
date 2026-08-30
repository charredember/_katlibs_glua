---@class _KSceneInternal
local internal = {}
local uid = 0

local getPriv
---CLIENT<br/>
---A handle to an active drawcall of a KScene.
---@class KSceneHandle
KSceneHandle,getPriv = KClass(nil,{
    Destructor = function(priv)
        priv.OnDestroy(priv.UID)
    end
})

local instantiate = getPriv(KSceneHandle).Instantiate

---@param bones table
---@param onDestroy fun(uid: integer)
---@return KSceneHandle
function internal.NewHandle(bones,onDestroy)
    uid = uid + 1
    return instantiate({
        UID = uid,
        ModelMatrix = Matrix(),
        Bones = bones,
        OnDestroy = onDestroy,
    })
end

function KSceneHandle:GetUID()
    return getPriv(self).UID
end

function KSceneHandle:GetModelMatrix()
    return getPriv(self).ModelMatrix
end

function KSceneHandle:GetBoneMatrix(boneIndex)
    local bones = getPriv(self).Bones

    local matrix = bones[boneIndex]
    if matrix then return matrix end

    matrix = Matrix()
    bones[boneIndex] = matrix
    return matrix
end

function KSceneHandle:Destroy()
    local priv = getPriv(self)
    priv.Valid = false
end

return internal