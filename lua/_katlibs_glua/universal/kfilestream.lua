local INT8_MAX = 127
local NULL_TERMINATOR = "\x00"

---@class File
local file_meta = FindMetaTable("File")
local f_Seek = file_meta.Seek
local f_Skip = file_meta.Skip
local f_Tell = file_meta.Tell
local f_Flush = file_meta.Flush
local f_Close = file_meta.Close
local f_Read = file_meta.Read
local f_Write = file_meta.Write
local f_EndOfFile = file_meta.EndOfFile
local f_ReadByte = file_meta.ReadByte
local f_WriteByte = file_meta.WriteByte
local f_ReadUShort = file_meta.ReadUShort
local f_WriteUShort = file_meta.WriteUShort
local f_ReadULong = file_meta.ReadULong
local f_WriteULong = file_meta.WriteULong
local f_ReadShort = file_meta.ReadShort
local f_WriteShort = file_meta.WriteShort
local f_ReadLong = file_meta.ReadLong
local f_WriteLong = file_meta.WriteLong
local f_ReadDouble = file_meta.ReadDouble
local f_WriteDouble = file_meta.WriteDouble
local f_ReadLine = file_meta.ReadLine
local f_WriteBool = file_meta.WriteBool
local f_ReadBool = file_meta.ReadBool

local string_char = string.char
local string_sub = string.sub

local math_huge = math.huge

local fileHandles = setmetatable({},{__mode = "k"})

---SHARED, OVERRIDE<br/>
---@class KFileStream : KStream
---@overload fun(path: string, mode: string, searchPath?: string): KFileStream
KFileStream = setmetatable({},{
    __call = function(_,path,mode,searchPath)
        local fileStream = file.Open(path,mode,searchPath or "GAME")
		if fileStream == nil then error("File does not exist or is locked!",2) end
		fileHandles[fileStream] = {
			Path = path,
			SearchPath = searchPath,
		}

        debug.setmetatable(fileStream,{__index = KFileStream})
        return fileStream
    end
})

do --set/get properties
	---SHARED, OVERRIDE<br/>
	---Sets the current read/write position of the stream.<br/>
	---Zero indexed.
	---@param int integer
	function KFileStream:Seek(int)
		f_Seek(self,int)
	end

	---SHARED, OVERRIDE<br/>
	---Skips the current read/write position forward by the specified amount of bytes.<br/>
	---@param int integer
	function KFileStream:Skip(int)
        f_Skip(self,int)
	end

	---SHARED, OVERRIDE<br/>
	---Resets the current read/write position back to zero.<br/>
	function KFileStream:Reset()
		f_Seek(self,0)
	end

	---SHARED, OVERRIDE<br/>
	---Gets the current read/write position of the stream.<br/>
	---Zero indexed.
	---@return integer
	function KFileStream:Tell()
		return f_Tell(self)
    end

	---SHARED<br/>
	---Saves changes to disk.<br/>
	---Zero indexed.
	function KFileStream:Save()
		return f_Flush(self)
    end

	---SHARED<br/>
	---Closes the filestream, saving changes.<br/>
	---Zero indexed.
	function KFileStream:Close()
		return f_Close(self)
    end

	---SHARED<br/>
	---Closes the filestream, saving changes.<br/>
	---Zero indexed.
	---@return KFileStream
	function KFileStream:ReopenWithMode(mode)
		f_Close(self)
		local properties = fileHandles[self]
		return KFileStream(properties.Path,mode,properties.SearchPath)
    end
end

do --read/write
	---SHARED, OVERRIDE<br/>
	---Reads the specified amount of bytes from the stream.
	---@param amount integer
	function KFileStream:Read(amount)
		return f_Read(self,amount)
	end

	---SHARED, OVERRIDE<br/>
	---Writes the specified bytes to the stream.
	---@param bytes string
	function KFileStream:Write(bytes)
        f_Write(self,bytes)
	end

	---SHARED, OVERRIDE<br/>
	---Reads from the byte stream until the specified character is read.
	---@param byte string
	function KFileStream:ReadUntil(byte)
		local bytes = ""
		if type(byte) == "number" then
			byte = string_char(byte)
		end

		local lastread
		while lastread ~= byte and not f_EndOfFile(self) do
			lastread = f_Read(self,1)
			bytes = bytes .. lastread
		end

		return string_sub(bytes,1,-2)
	end

	---SHARED, OVERRIDE<br/>
	---Reads an 8-bit unsigned integer from the byte stream.
	---@return integer
	function KFileStream:ReadUInt8()
		return f_ReadByte(self)
	end

	---SHARED, OVERRIDE<br/>
	---Writes an 8-bit unsigned integer to the byte stream.
	---@param int integer
	function KFileStream:WriteUInt8(int)
		f_WriteByte(self,int)
	end

	--SHARED<br/>
	---Reads a 16-bit unsigned integer from the byte stream.
	---@return integer
	function KFileStream:ReadUInt16()
		return f_ReadUShort(self)
	end

	---SHARED, OVERRIDE<br/>
	---Writes a 16-bit unsigned integer to the byte stream.
	---@param int integer
	function KFileStream:WriteUInt16(int)
		f_WriteUShort(self,int)
	end

	--SHARED<br/>
	---Reads a 32-bit unsigned integer from the byte stream.
	---@return integer
	function KFileStream:ReadUInt32()
		return f_ReadULong(self)
	end

	--SHARED<br/>
	---Writes a 32-bit unsigned integer from the byte stream.
	---@param int integer
	function KFileStream:WriteUInt32(int)
		f_WriteULong(self,int)
	end

	---SHARED, OVERRIDE<br/>
	---Reads an 8-bit signed integer from the byte stream.
	function KFileStream:ReadInt8()
		local int = f_ReadByte(self)
		if int > INT8_MAX then int = int - 0x100 end
		return int
	end

	---SHARED, OVERRIDE<br/>
	---Writes an 8-bit signed integer to the byte stream.
	---@param int integer
	function KFileStream:WriteInt8(int)
        if int == math_huge or int == -math_huge or int ~= int then
            error("Not an int8!", 2)
        end

	    if int < 0 then int = int + 0x100 end

	    f_WriteByte(self,int % 0x100)
	end

	---SHARED, OVERRIDE<br/>
	---Reads a 16-bit signed integer from the byte stream.
	function KFileStream:ReadInt16()
		return f_ReadShort(self)
	end

	---SHARED, OVERRIDE<br/>
	---Writes a 16-bit signed integer to the byte stream.
	---@param int integer
	function KFileStream:WriteInt16(int)
		f_WriteShort(self,int)
	end

	---SHARED, OVERRIDE<br/>
	---Reads a 32-bit signed integer from the byte stream.
	function KFileStream:ReadInt32()
		return f_ReadLong(self)
	end

	---SHARED, OVERRIDE<br/>
	---Writes a 32-bit signed integer to the byte stream.
	---@param int integer
	function KFileStream:WriteInt32(int)
		f_WriteLong(self,int)
	end

	---SHARED, OVERRIDE<br/>
	---Writes a 64-bit IEEE754 double to the byte stream.
	function KFileStream:ReadDouble()
		return f_ReadDouble(self)
	end

	---SHARED, OVERRIDE<br/>
	---Reads a 64-bit IEEE754 double from the byte stream.
	---@param double number
	function KFileStream:WriteDouble(double)
		f_WriteDouble(self,double)
	end

	---SHARED, OVERRIDE<br/>
	---Reads a string from the byte stream.
	function KFileStream:ReadString()
		local read = f_ReadLine(self)
		return string_sub(read,1,#read - 1)
	end

	---SHARED, OVERRIDE<br/>
	---Writes a string to the byte stream.
	---@param str string
	function KFileStream:WriteString(str)
		f_Write(self,str .. NULL_TERMINATOR)
	end

	---SHARED, OVERRIDE<br/>
	---Writes a bool to the byte stream.
	---@param bool boolean
	function KFileStream:WriteBool(bool)
		f_WriteBool(self,bool)
	end

	---SHARED, OVERRIDE<br/>
	---Reads a bool from the byte stream.
	function KFileStream:ReadBool()
		return f_ReadBool(self)
	end

	---SHARED, OVERRIDE<br/>
	---Writes a Vector to the byte stream.
	---@param vec Vector
	function KFileStream:WriteVector(vec)
		f_WriteDouble(self,vec.x)
		f_WriteDouble(self,vec.y)
		f_WriteDouble(self,vec.z)
	end

	---SHARED, OVERRIDE<br/>
	---Reads a Vector from the byte stream.
	function KFileStream:ReadVector()
		return Vector(
			f_ReadDouble(self),
			f_ReadDouble(self),
			f_ReadDouble(self))
	end

	---SHARED, OVERRIDE<br/>
	---Writes a Color to the byte stream.
	---@param color Color
	function KFileStream:WriteColor(color)
		f_WriteByte(self,color.r)
		f_WriteByte(self,color.g)
		f_WriteByte(self,color.b)
		f_WriteByte(self,color.a)
	end

	---SHARED, OVERRIDE<br/>
	---Reads a Color from the byte stream.
	function KFileStream:ReadColor()
		return Color(
			f_ReadByte(self),
			f_ReadByte(self),
			f_ReadByte(self),
			f_ReadByte(self))
	end
end