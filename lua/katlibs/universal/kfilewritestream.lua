local NULL_TERMINATOR = "\x00"

---@class File
local file_meta = FindMetaTable("File")
local f_Close = file_meta.Close
local f_Write = file_meta.Write
local f_WriteByte = file_meta.WriteByte
local f_WriteUShort = file_meta.WriteUShort
local f_WriteULong = file_meta.WriteULong
local f_WriteShort = file_meta.WriteShort
local f_WriteLong = file_meta.WriteLong
local f_WriteDouble = file_meta.WriteDouble
local f_WriteFloat = file_meta.WriteFloat
local f_WriteBool = file_meta.WriteBool

local math_huge = math.huge

local fileHandles = setmetatable({},{__mode = "k"})

---SHARED, OVERRIDE<br/>
---KStream wrapper for file.
---@class KFileWriteStream : KWriteStream
---@overload fun(path: string): KFileWriteStream
KFileWriteStream = setmetatable({},{
    __call = function(_,path,searchPath)
        local fileStream = file.Open(path,"wb","DATA")
		if fileStream == nil then error("File does not exist or is locked!",2) end
		fileHandles[fileStream] = path

        debug.setmetatable(fileStream,{__index = KFileWriteStream})
        return fileStream
    end
})

do --set/get properties
	---SHARED, OVERRIDE<br/>
	---Discards the current stream object and reopens it as its KReadStream variant.<br/>
	---Zero indexed.
	---@return KReadStream
	function KFileWriteStream:ReopenAsReadStream()
		f_Close(self)
		return KFileReadStream(fileHandles[self])
    end

	---SHARED<br/>
	---Closes the filestream, saving changes.<br/>
	---Zero indexed.
	function KFileWriteStream:Close()
		return f_Close(self)
    end
end

do --read/write
	---SHARED, OVERRIDE<br/>
	---Writes the specified bytes to the stream.
	---@param bytes string
	function KFileWriteStream:Write(bytes)
        f_Write(self,bytes)
	end

	---SHARED, OVERRIDE<br/>
	---Writes an 8-bit unsigned integer to the byte stream.
	---@param int integer
	function KFileWriteStream:WriteUInt8(int)
		f_WriteByte(self,int)
	end

	---SHARED, OVERRIDE<br/>
	---Writes a 16-bit unsigned integer to the byte stream.
	---@param int integer
	function KFileWriteStream:WriteUInt16(int)
		f_WriteUShort(self,int)
	end

	--SHARED<br/>
	---Writes a 32-bit unsigned integer from the byte stream.
	---@param int integer
	function KFileWriteStream:WriteUInt32(int)
		f_WriteULong(self,int)
	end

	---SHARED, OVERRIDE<br/>
	---Writes an 8-bit signed integer to the byte stream.
	---@param int integer
	function KFileWriteStream:WriteInt8(int)
        if int == math_huge or int == -math_huge or int ~= int then
            error("Not an int8!", 2)
        end

	    if int < 0 then int = int + 0x100 end

	    f_WriteByte(self,int % 0x100)
	end

	---SHARED, OVERRIDE<br/>
	---Writes a 16-bit signed integer to the byte stream.
	---@param int integer
	function KFileWriteStream:WriteInt16(int)
		f_WriteShort(self,int)
	end

	---SHARED, OVERRIDE<br/>
	---Writes a 32-bit signed integer to the byte stream.
	---@param int integer
	function KFileWriteStream:WriteInt32(int)
		f_WriteLong(self,int)
	end

	---SHARED, OVERRIDE<br/>
	---Reads a 64-bit IEEE754 double from the byte stream.
	---@param float number
	function KFileWriteStream:WriteFloat(float)
		f_WriteFloat(self,float)
	end

	---SHARED, OVERRIDE<br/>
	---Reads a 64-bit IEEE754 double from the byte stream.
	---@param double number
	function KFileWriteStream:WriteDouble(double)
		f_WriteDouble(self,double)
	end

	---SHARED, OVERRIDE<br/>
	---Writes a string to the byte stream.
	---@param str string
	function KFileWriteStream:WriteString(str)
		f_Write(self,str .. NULL_TERMINATOR)
	end

	---SHARED, OVERRIDE<br/>
	---Writes a bool to the byte stream.
	---@param bool boolean
	function KFileWriteStream:WriteBool(bool)
		f_WriteBool(self,bool)
	end

	---SHARED, OVERRIDE<br/>
	---Writes a Vector to the byte stream using 64-bit doubles.
	---@param vec Vector
	function KFileWriteStream:WriteVector(vec)
		f_WriteDouble(self,vec.x)
		f_WriteDouble(self,vec.y)
		f_WriteDouble(self,vec.z)
	end

	---SHARED, OVERRIDE<br/>
	---Writes a Vector to the byte stream using 32-bit floats.
	---@param vec Vector
	function KFileWriteStream:WriteVectorF(vec)
		f_WriteFloat(self,vec.x)
		f_WriteFloat(self,vec.y)
		f_WriteFloat(self,vec.z)
	end

	---SHARED, OVERRIDE<br/>
	---Writes a Color to the byte stream.
	---@param color Color
	function KFileWriteStream:WriteColor(color)
		f_WriteByte(self,color.r)
		f_WriteByte(self,color.g)
		f_WriteByte(self,color.b)
		f_WriteByte(self,color.a)
	end
end