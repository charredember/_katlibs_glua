local INT8_MAX = 127

---@class File
local file_meta = FindMetaTable("File")
local f_Seek = file_meta.Seek
local f_Skip = file_meta.Skip
local f_Tell = file_meta.Tell
local f_Close = file_meta.Close
local f_Read = file_meta.Read
local f_EndOfFile = file_meta.EndOfFile
local f_ReadByte = file_meta.ReadByte
local f_ReadUShort = file_meta.ReadUShort
local f_ReadULong = file_meta.ReadULong
local f_ReadShort = file_meta.ReadShort
local f_ReadLong = file_meta.ReadLong
local f_ReadDouble = file_meta.ReadDouble
local f_ReadLine = file_meta.ReadLine
local f_ReadBool = file_meta.ReadBool

local string_char = string.char
local string_sub = string.sub

local fileHandles = setmetatable({},{__mode = "k"})

---SHARED, OVERRIDE<br/>
---@class KFileReadStream : KReadStream
---@overload fun(path: string): KFileReadStream
KFileReadStream = setmetatable({},{
    __call = function(_,path)
        local fileStream = file.Open(path,"rb","DATA")
		if fileStream == nil then error("File does not exist or is locked!",2) end
		fileHandles[fileStream] = path

        debug.setmetatable(fileStream,{__index = KFileReadStream})
        return fileStream
    end
})

do --set/get properties
	---SHARED, OVERRIDE<br/>
	---Sets the current read/write position of the stream.<br/>
	---Zero indexed.
	---@param int integer
	function KFileReadStream:Seek(int)
		f_Seek(self,int)
	end

	---SHARED, OVERRIDE<br/>
	---Skips the current read/write position forward by the specified amount of bytes.<br/>
	---@param int integer
	function KFileReadStream:Skip(int)
        f_Skip(self,int)
	end

	---SHARED, OVERRIDE<br/>
	---Resets the current read/write position back to zero.<br/>
	function KFileReadStream:Reset()
		f_Seek(self,0)
	end

	---SHARED, OVERRIDE<br/>
	---Gets the current read/write position of the stream.<br/>
	---Zero indexed.
	---@return integer
	function KFileReadStream:Tell()
		return f_Tell(self)
    end

	---SHARED, OVERRIDE<br/>
	---Discards the current stream object and reopens it as its KWriteStream variant.<br/>
	---Zero indexed.
	---@return KWriteStream
	function KFileReadStream:ReopenAsWriteStream()
		f_Close(self)
		return KFileWriteStream(fileHandles[self])
    end

	---SHARED<br/>
	---Closes the filestream.<br/>
	---Zero indexed.
	function KFileReadStream:Close()
		return f_Close(self)
    end
end

do --read/write
	---SHARED, OVERRIDE<br/>
	---Reads the specified amount of bytes from the stream.
	---@param amount integer
	function KFileReadStream:Read(amount)
		return f_Read(self,amount)
	end

	---SHARED, OVERRIDE<br/>
	---Reads from the byte stream until the specified character is read.
	---@param byte string
	function KFileReadStream:ReadUntil(byte)
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
	function KFileReadStream:ReadUInt8()
		return f_ReadByte(self)
	end

	--SHARED<br/>
	---Reads a 16-bit unsigned integer from the byte stream.
	---@return integer
	function KFileReadStream:ReadUInt16()
		return f_ReadUShort(self)
	end

	--SHARED<br/>
	---Reads a 32-bit unsigned integer from the byte stream.
	---@return integer
	function KFileReadStream:ReadUInt32()
		return f_ReadULong(self)
	end

	---SHARED, OVERRIDE<br/>
	---Reads an 8-bit signed integer from the byte stream.
	function KFileReadStream:ReadInt8()
		local int = f_ReadByte(self)
		if int > INT8_MAX then int = int - 0x100 end
		return int
	end

	---SHARED, OVERRIDE<br/>
	---Reads a 16-bit signed integer from the byte stream.
	function KFileReadStream:ReadInt16()
		return f_ReadShort(self)
	end

	---SHARED, OVERRIDE<br/>
	---Reads a 32-bit signed integer from the byte stream.
	function KFileReadStream:ReadInt32()
		return f_ReadLong(self)
	end

	---SHARED, OVERRIDE<br/>
	---Writes a 64-bit IEEE754 double to the byte stream.
	function KFileReadStream:ReadDouble()
		return f_ReadDouble(self)
	end

	---SHARED, OVERRIDE<br/>
	---Reads a string from the byte stream.
	function KFileReadStream:ReadString()
		local read = f_ReadLine(self)
		return string_sub(read,1,#read - 1)
	end

	---SHARED, OVERRIDE<br/>
	---Reads a bool from the byte stream.
	function KFileReadStream:ReadBool()
		return f_ReadBool(self)
	end

	---SHARED, OVERRIDE<br/>
	---Reads a Vector from the byte stream.
	function KFileReadStream:ReadVector()
		return Vector(
			f_ReadDouble(self),
			f_ReadDouble(self),
			f_ReadDouble(self))
	end

	---SHARED, OVERRIDE<br/>
	---Reads a Color from the byte stream.
	function KFileReadStream:ReadColor()
		return Color(
			f_ReadByte(self),
			f_ReadByte(self),
			f_ReadByte(self),
			f_ReadByte(self))
	end
end