local EPSILON_QUATERNION = 1e-4

---@class Vector
local vec_meta = FindMetaTable("Vector")
local v_Unpack = vec_meta.Unpack
local v_SetUnpacked = vec_meta.SetUnpacked
local v_Normalize = vec_meta.Normalize
---@class Angle
local ang_meta = FindMetaTable("Angle")
local a_Unpack = ang_meta.Unpack
local a_SetUnpacked = ang_meta.SetUnpacked
---@class VMatrix
local vm_meta = FindMetaTable("VMatrix")
local vm_SetScale = vm_meta.SetScale
local vm_SetUnpacked = vm_meta.SetUnpacked
local vm_Unpack = vm_meta.Unpack
local m_asin = math.asin
local m_acos = math.acos
local m_atan2 = math.atan2
local m_cos = math.cos
local m_sin = math.sin
local m_rad = math.rad
local m_deg = math.deg
local m_sqrt = math.sqrt
local m_clamp = math.Clamp
local m_abs = math.abs
local m_max = math.max
local m_pi = math.pi
local s_format = string.format
local select = select
local type = type
local is = KClass.Is

local R = 0
local I = 1
local J = 2
local K = 3

local sign
local multiplyByNumber,multiplyByQuat,multiplyByVector
local divideByNumber,inverseDividedByNumber,divideByQuat
local getPriv,copy,q_unpack

do --constructors
    ---SHARED<br/>
    ---Quaternion implementation.
    ---@class KQuaternion
    ---@overload fun(r: number, i: number, j: number, k: number): KQuaternion
    KQuaternion,getPriv = KClass(function(r,i,j,k)
        return {
            [R] = r,
            [I] = i,
            [J] = j,
            [K] = k,
        }
    end)

    ---SHARED, STATIC<br/>
    ---Creates a new KQuaternion from a scalar angle and a unit vector.
    ---@param a number
    ---@param v Vector
    ---@return KQuaternion
    function KQuaternion.FromAxisAngle(a,v)
        local new = KQuaternion(0,0,0,0)
        new:SetAxisAngle(a,v)
        return new
    end

    ---SHARED, STATIC<br/>
    ---Creates a new KQuaternion from an Euler angle.
    ---@param ang Angle
    ---@return KQuaternion
    function KQuaternion.FromEulerAngle(ang)
        local new = KQuaternion(0,0,0,0)
        new:SetEulerAngle(ang)
        return new
    end

    ---SHARED, STATIC<br/>
    ---Creates a new KQuaternion from an Matrix.
    ---@param m VMatrix
    ---@return KQuaternion
    function KQuaternion.FromMatrix(m)
        local new = KQuaternion(0,0,0,0)
        new:SetMatrix(m)
        return new
    end

    ---SHARED, STATIC<br/>
    ---Creates a new Identity KQuaternion.
    ---@return KQuaternion
    function KQuaternion.FromIdentity()
        return KQuaternion(1,0,0,0)
    end

    ---SHARED<br/>
    ---Creates a new KQuaternion from an existing KQuaternion.
    ---@return KQuaternion
    function KQuaternion:Copy()
        return copy(getPriv(self))
    end
end

do --set/get
    ---SHARED<br/>
    ---Gets the scalar angle and unit vector axis of the quaternion.<br/>
    ---GARBAGE EFFICIENT: Does not create any new objects if an object is passed in.
    ---@param v? Vector An optional Vector to pass in to populate instead of creating a new Vector.
    ---@return number,Vector
    function KQuaternion:GetAxisAngle(v)
        v = v or Vector(0,0,0)
        local priv = getPriv(self)

        local r = priv[R]
        local a = 2.0 * m_acos(r)
        local divider = m_sqrt(1.0 - r * r)

        if divider ~= 0.0 then
            v_SetUnpacked(v,
                priv[I] / divider,
                priv[J] / divider,
                priv[K] / divider
            )
        else
            v.x = 1
        end

        return m_deg(a),v
    end

    ---SHARED<br/>
    ---Sets the scalar angle and unit vector axis of the quaternion.
    ---@param a number
    ---@param v Vector
    function KQuaternion:SetAxisAngle(a,v)
        local priv = getPriv(self)
        local r = m_rad(a)
        local c = m_sin(r / 2.0)

        v_Normalize(v)
        local x,y,z = v_Unpack(v)
        priv[R] = m_cos(r / 2.0)
        priv[I] = c * x
        priv[J] = c * y
        priv[K] = c * z
    end

    local scale = Vector()
    ---SHARED<br/>
    ---Gets the matrix representation of the quaternion.<br/>
    ---GARBAGE EFFICIENT: Does not create any new objects if an object is passed in.
    ---@param m? VMatrix An optional VMatrix to pass in to populate instead of creating a new VMatrix. Only changes rotation, keeps translation and scale.
    ---@return VMatrix
    function KQuaternion:GetMatrix(m)
        m = m or Matrix()
        local r,i,j,k = q_unpack(getPriv(self))
        local m11,m12,m13,m14,m21,m22,m23,m24,m31,m32,m33,m34 = vm_Unpack(m)

        v_SetUnpacked(scale,
            m_sqrt(m11 * m11 + m21 * m21 + m31 * m31),
            m_sqrt(m12 * m12 + m22 * m22 + m32 * m32),
            m_sqrt(m13 * m13 + m23 * m23 + m33 * m33)
        )
        vm_SetUnpacked(m,
            1 - 2*j*j - 2*k*k,	2*i*j - 2*k*r,		2*i*k + 2*j*r,		m14,
            2*i*j + 2*k*r,		1 - 2*i*i - 2*k*k,	2*j*k - 2*i*r,		m24,
            2*i*k - 2*j*r,		2*j*k + 2*i*r,		1 - 2*i*i - 2*j*j,	m34,
            0,				    0,				    0,				    1
        )
        vm_SetScale(m,scale)

        return m
    end

    ---SHARED<br/>
    ---Sets the rotation from the quaternion of a VMatrix.
    ---@param m VMatrix
    function KQuaternion:SetMatrix(m)
        local priv = getPriv(self)
        local m11,m12,m13,_,m21,m22,m23,_,m31,m32,m33 = vm_Unpack(m)

        priv[R] = m_sqrt(m_max(0,1 + m11 + m22 + m33)) / 2
        local i = m_sqrt(m_max(0,1 + m11 - m22 - m33)) / 2
        local j = m_sqrt(m_max(0,1 - m11 + m22 - m33)) / 2
        local k = m_sqrt(m_max(0,1 - m11 - m22 + m33)) / 2
        priv[I] = i * sign(i * (m32 - m23))
        priv[J] = j * sign(j * (m13 - m31))
        priv[K] = k * sign(k * (m21 - m12))
    end

    ---SHARED<br/>
    ---Gets the euler angle representation of the quaternion.<br/>
    ---GARBAGE EFFICIENT: Does not create any new objects if an object is passed in.
    ---@param ang? Angle An optional Angle to pass in to populate instead of creating a new Angle.
    ---@return Angle
    function KQuaternion:GetEulerAngle(ang)
        ang = ang or Angle(0,0,0)
        local r,i,j,k = q_unpack(getPriv(self))

        local pitch,yaw,roll
        local sinp = 2.0 * (r * j - k * i)
        if m_abs(sinp) >= 1 then
            pitch = m_clamp(m_deg(m_pi / 2),-90,90)
        else
            pitch = m_deg(m_asin(sinp))
        end

        local siny_cosp = 2.0 * (r * k + i * j)
        local cosy_cosp = 1.0 - 2.0 * (j * j + k * k)
        yaw = m_deg(m_atan2(siny_cosp, cosy_cosp))

        local sinr_cosp = 2.0 * (r * i + j * k)
        local cosr_cosp = 1.0 - 2.0 * (i * i + j * j)
        roll = m_deg(m_atan2(sinr_cosp, cosr_cosp))

        a_SetUnpacked(ang,pitch,yaw,roll)
        return ang
    end

    ---SHARED<br/>
    ---Sets the euler angle representation of the quaternion.
    ---@param ang Angle
    function KQuaternion:SetEulerAngle(ang)
        local priv = getPriv(self)
        local pitch,yaw,roll = a_Unpack(ang)
        local p = m_rad(pitch)
        local y = m_rad(yaw)
        local r = m_rad(roll)

        local cp = m_cos(p * 0.5)
        local sp = m_sin(p * 0.5)
        local cy = m_cos(y * 0.5)
        local sy = m_sin(y * 0.5)
        local cr = m_cos(r * 0.5)
        local sr = m_sin(r * 0.5)

        priv[R] = cy * cr * cp + sy * sr * sp
        priv[I] = cy * sr * cp - sy * cr * sp
        priv[J] = cy * cr * sp + sy * sr * cp
        priv[K] = sy * cr * cp - cy * sr * sp
    end

    ---SHARED<br/>
    ---Returns the scalar length of the quaternion.
    function KQuaternion:GetLength()
        local priv = getPriv(self)
        local r,i,j,k = q_unpack(priv)
        return m_sqrt(r * r + i * i + j * j + k * k)
    end

    ---SHARED<br/>
    ---Returns the squared scalar length of the quaternion.
    function KQuaternion:GetLengthSqr()
        local priv = getPriv(self)
        local r,i,j,k = q_unpack(priv)
        return r * r + i * i + j * j + k * k
    end

    ---SHARED<br/>
    ---Gets the R (real) component of the quaternion.
    ---@return number
    function KQuaternion:GetR()
        return getPriv(self)[R]
    end

    ---SHARED<br/>
    ---Sets the R (real) component of the quaternion.
    ---@param val number
    function KQuaternion:SetR(val)
        getPriv(self)[R] = val
    end

    ---SHARED<br/>
    ---Gets the I (real) component of the quaternion.
    ---@return number
    function KQuaternion:GetI()
        return getPriv(self)[I]
    end

    ---SHARED<br/>
    ---Sets the I component of the quaternion.
    ---@param val number
    function KQuaternion:SetI(val)
        getPriv(self)[I] = val
    end

    ---SHARED<br/>
    ---Gets the J component of the quaternion.
    ---@return number
    function KQuaternion:GetJ()
        return getPriv(self)[J]
    end

    ---SHARED<br/>
    ---Sets the J component of the quaternion.
    ---@param val number
    function KQuaternion:SetJ(val)
        getPriv(self)[J] = val
    end

    ---SHARED<br/>
    ---Gets the K component of the quaternion.
    ---@return number
    function KQuaternion:GetK()
        return getPriv(self)[K]
    end

    ---SHARED<br/>
    ---Sets the K component of the quaternion.
    ---@param val number
    function KQuaternion:SetK(val)
        getPriv(self)[K] = val
    end

    ---SHARED<br/>
    ---Gets the components of the quaternion.
    ---@return number r, number i, number j, number k
    function KQuaternion:Unpack()
        return q_unpack(getPriv(self))
    end

    ---SHARED<br/>
    ---Sets the components of the quaternion.
    ---@param r number
    ---@param i number
    ---@param j number
    ---@param k number
    function KQuaternion:SetUnpacked(r,i,j,k)
        local priv = getPriv(self)

        priv[R] = r
        priv[I] = i
        priv[J] = j
        priv[K] = k
    end
end

do --special operations
    ---SHARED<br/>
    ---Conjugates the quaternion.<br/>
    ---GARBAGE EFFICIENT: Self modifies. Does not allocate any new objects.
    function KQuaternion:Conjugate()
        local priv = getPriv(self)

        priv[I] = -priv[I]
        priv[J] = -priv[J]
        priv[K] = -priv[K]
    end

    ---SHARED<br/>
    ---Returns a new conjugated KQuaternion object.<br/>
    function KQuaternion:GetConjugate()
        local q = copy(getPriv(self))
        q:Conjugate()
        return q
    end

    ---SHARED<br/>
    ---Normalizes the quaternion.<br/>
    ---GARBAGE EFFICIENT: Self modifies. Does not allocate any new objects.
    function KQuaternion:Normalize()
        local priv = getPriv(self)

        local r,i,j,k = q_unpack(priv)
        local len = m_sqrt(r * r + i * i + j * j + k * k)

        priv[R] = r / len
        priv[I] = i / len
        priv[J] = j / len
        priv[K] = k / len
    end

    ---SHARED<br/>
    ---Returns a new normalized KQuaternion object.<br/>
    function KQuaternion:GetNormalized()
        local q = copy(getPriv(self))
        q:Normalize()
        return q
    end

    ---SHARED<br/>
    ---Inverts the quaternion.<br/>
    ---GARBAGE EFFICIENT: Self modifies. Does not allocate any new objects.
    function KQuaternion:Invert()
        local priv = getPriv(self)
        local r,i,j,k = q_unpack(priv)

        local lenSqr = r * r + i * i + j * j + k * k
        if lenSqr <= 0 then return end

        priv[R] = r / lenSqr
        priv[I] = -i / lenSqr
        priv[J] = -j / lenSqr
        priv[K] = -k / lenSqr
    end

    ---SHARED<br/>
    ---Returns a new inverted KQuaternion object.<br/>
    ---@return KQuaternion
    function KQuaternion:GetInverse()
        local q = copy(getPriv(self))
        q:Invert()
        return q
    end

    ---SHARED<br/>
    ---Resets the quaternion to the quaternion identity value.<br/>
    ---GARBAGE EFFICIENT: Self modifies. Does not allocate any new objects.
    function KQuaternion:Identity()
        local priv = getPriv(self)

        priv[R] = 1
        priv[I] = 0
        priv[J] = 0
        priv[K] = 0
    end

    ---SHARED<br/>
    ---Rotates a passed vector by the rotation of this quaternion.<br/>
    ---GARBAGE EFFICIENT: Does not allocate any new objects.
    ---@param v Vector
    function KQuaternion:RotateVector(v)
        multiplyByVector(v,getPriv(self),v)
    end

    ---SHARED, STATIC<br/>
    ---Performs spherical interpolation between to two other quaternions and stores it in the first argument.<br/>
    ---GARBAGE EFFICIENT: Does not allocate any new objects.
    function KQuaternion.SLerp(qResult,t,q1,q2)
        local priv = getPriv(qResult)
        local r1,i1,j1,k1 = q_unpack(getPriv(q1))
        local r2,i2,j2,k2 = q_unpack(getPriv(q2))

        local cosHalfTheta = r1 * r2 + i1 * i2 + j1 * j2 + k1 * k2
        if m_abs(cosHalfTheta) >= 1.0 then return end

        local halfTheta = m_acos(cosHalfTheta)
        local sinHalfTheta = m_sqrt(1.0 - cosHalfTheta * cosHalfTheta)

        if m_abs(sinHalfTheta) < EPSILON_QUATERNION then
            priv[R] = r1 * 0.5 + r2 * 0.5
            priv[I] = i1 * 0.5 + i2 * 0.5
            priv[J] = j1 * 0.5 + j2 * 0.5
            priv[K] = k1 * 0.5 + k2 * 0.5
        else
            local ratioA = m_sin((1 - t) * halfTheta) / sinHalfTheta
            local ratioB = m_sin(t * halfTheta) / sinHalfTheta
            priv[R] = r1 * ratioA + r2 * ratioB
            priv[I] = i1 * ratioA + i2 * ratioB
            priv[J] = j1 * ratioA + j2 * ratioB
            priv[K] = k1 * ratioA + k2 * ratioB
        end
    end

    ---SHARED, STATIC<br/>
    ---Multiplies passed quaternions from right to left and stores the result in the first argument.<br/>
    ---GARBAGE EFFICIENT: Does not allocate any new objects.
    ---@param qResult KQuaternion
    ---@param ... KQuaternion
    function KQuaternion.Multiply(qResult,...)
        local privResult = getPriv(qResult)

        privResult[R] = 1
        privResult[I] = 0
        privResult[J] = 0
        privResult[K] = 0

        for i = select("#",...), 1, -1 do
            local q = select(i,...)
            multiplyByQuat(privResult,getPriv(q),privResult)
        end
    end
end

do --metafunctions
    local meta = getPriv(KQuaternion).GetObjectMeta()

    ---@class KQuaternion
    ---@operator mul(KQuaternion): KQuaternion
    ---@operator mul(number): KQuaternion
    ---@operator div(KQuaternion): KQuaternion
    ---@operator div(number): KQuaternion
    ---@operator add(KQuaternion): KQuaternion
    ---@operator add(number): KQuaternion
    ---@operator sub(KQuaternion): KQuaternion
    ---@operator sub(number): KQuaternion
    ---@operator unm:KQuaternion

    meta.__mul = function(q1n, q2nv)
        local new = KQuaternion(0,0,0,0)
        local privNew = getPriv(new)

        if is(q1n,KQuaternion) then
            local privQ1 = getPriv(q1n)

            if is(q2nv,KQuaternion) then
                multiplyByQuat(privNew,privQ1,getPriv(q2nv))
                return new
            end

            if type(q2nv) == "number" then
                multiplyByNumber(privNew,privQ1,q2nv)
                return new
            end
        end

        if type(q1n) == "number" and is(q2nv,KQuaternion) then
            multiplyByNumber(privNew,getPriv(q2nv),q1n)
            return new
        end

        error("Type not supported by this operation!",2)
    end

    meta.__div = function(q1n, q2nv)
        local new = KQuaternion(0,0,0,0)
        local privNew = getPriv(new)

        if is(q1n,KQuaternion) then
            local privQ1 = getPriv(q1n)

            if is(q2nv,KQuaternion) then
                divideByQuat(privNew,privQ1,getPriv(q2nv))
                return new
            end

            if type(q2nv) == "number" then
                divideByNumber(privNew,privQ1,q2nv)
                return new
            end
        end

        if type(q1n) == "number" and is(q2nv,KQuaternion) then
            inverseDividedByNumber(privNew,getPriv(q2nv),q1n)
            return new
        end

        error("Type not supported by this operation!",2)
    end

    meta.__add = function(q1, q2)
        local r1,i1,j1,k1 = q_unpack(getPriv(q1))
        local r2,i2,j2,k2 = q_unpack(getPriv(q2))
        return KQuaternion(r1 + r2, i1 + i2, j1 + j2, k1 + k2)
    end

    meta.__sub = function(q1, q2)
        local r1,i1,j1,k1 = q_unpack(getPriv(q1))
        local r2,i2,j2,k2 = q_unpack(getPriv(q2))
        return KQuaternion(r1 - r2, i1 - i2, j1 - j2, k1 - k2)
    end

    meta.__unm = function(q)
        local r,i,j,k = q_unpack(getPriv(q))
        return KQuaternion(-r,-i,-j,-k)
    end

    meta.__eq = function(q1, q2)
        local r1,i1,j1,k1 = q_unpack(getPriv(q1))
        local r2,i2,j2,k2 = q_unpack(getPriv(q2))

        return m_abs(r2 - r1) <= EPSILON_QUATERNION
            and m_abs(i2 - i1) <= EPSILON_QUATERNION
            and m_abs(j2 - j1) <= EPSILON_QUATERNION
            and m_abs(k2 - k1) <= EPSILON_QUATERNION
    end

    meta.__tostring = function(q)
        return s_format("%.6f %.6f %.6f %.6f",q_unpack(getPriv(q)))
    end
end

do --helper functions
    function multiplyByNumber(privResult,priv,num)
        privResult[R] = priv[R] * num
        privResult[I] = priv[I] * num
        privResult[J] = priv[J] * num
        privResult[K] = priv[K] * num
    end

    function divideByNumber(privResult,priv,num)
        privResult[R] = priv[R] / num
        privResult[I] = priv[I] / num
        privResult[J] = priv[J] / num
        privResult[K] = priv[K] / num
    end

    function inverseDividedByNumber(privResult,priv,num)
        local r,i,j,k = q_unpack(priv)
        local lenSqr = r * r + i * i + j * j + k * k

        if lenSqr <= 0 then
            local nan = 0 / 0
            return KQuaternion(nan,nan,nan,nan)
        end

        local n = lenSqr / num

        privResult[R] =  r / n
        privResult[I] = -i / n
        privResult[J] = -j / n
        privResult[K] = -k / n
    end

    function multiplyByQuat(privResult,privQ1,privQ2)
        local r1,i1,j1,k1 = q_unpack(privQ1)
        local r2,i2,j2,k2 = q_unpack(privQ2)

        privResult[R] =  r1 * r2 - i1 * i2 - j1 * j2 - k1 * k2
        privResult[I] =  i1 * r2 + r1 * i2 + j1 * k2 - k1 * j2
        privResult[J] =  r1 * j2 - i1 * k2 + j1 * r2 + k1 * i2
        privResult[K] =  r1 * k2 + i1 * j2 - j1 * i2 + k1 * r2
    end

    function divideByQuat(privResult,privQ1,privQ2)
        local r1,i1,j1,k1 = q_unpack(privQ1)
        local r2,i2,j2,k2 = q_unpack(privQ2)
        local lenSqr = r2 * r2 + i2 * i2 + j2 * j2 + k2 * k2

        local cr2,ci2,cj2,ck2 = r2,-i2,-j2,-k2

        privResult[R] = (r1 * cr2 - i1 * ci2 - j1 * cj2 - k1 * ck2) / lenSqr
        privResult[I] = (i1 * cr2 + r1 * ci2 + j1 * ck2 - k1 * cj2) / lenSqr
        privResult[J] = (r1 * cj2 - i1 * ck2 + j1 * cr2 + k1 * ci2) / lenSqr
        privResult[K] = (r1 * ck2 + i1 * cj2 - j1 * ci2 + k1 * cr2) / lenSqr
    end

    function multiplyByVector(vout,priv,vin)
        local x,y,z = v_Unpack(vin)
        local r,i,j,k = q_unpack(priv)

        local rr = r * r
        local ii = i * i
        local jj = j * j
        local kk = k * k
        local ri = r * i
        local rj = r * j
        local rk = r * k
        local ij = i * j
        local ik = i * k
        local jk = j * k

        v_SetUnpacked(vout,
            rr * x + 2 * rj * z - 2 * rk * y + ii * x + 2 * ij * y + 2 * ik * z - kk * x - jj * x,
            2 * ij * x + jj * y + 2 * jk * z + 2 * rk * x - kk * y + rr * y - 2 * ri * z - ii * y,
            2 * ik * x + 2 * jk * y + kk * z - 2 * rj * x - jj * z + 2 * ri * y - ii * z + rr * z
        )
    end

    function copy(priv)
        return KQuaternion(priv[R],priv[I],priv[J],priv[K])
    end

    function q_unpack(priv)
        local r = priv[R]
        local i = priv[I]
        local j = priv[J]
        local k = priv[K]

        return r,i,j,k
    end

    function sign(n)
        return n > 0 and 1 or -1
    end
end