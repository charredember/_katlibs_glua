local function AddSubDirectoriesToCSLua(directory)
	local _,directories = file.Find(directory .. "*","LUA")
    for _,subDirectoryName in pairs(directories) do
        local subDirectory = string.format("%s%s/",directory,subDirectoryName)
        local files = file.Find(subDirectory .. "*","LUA")
        for _,file in pairs(files) do
            if not string.EndsWith(file,".lua") then continue end
            AddCSLuaFile(subDirectory .. file)
        end
    end
end

AddSubDirectoriesToCSLua("katlibs/client/")
AddSubDirectoriesToCSLua("katlibs/universal/")
AddSubDirectoriesToCSLua("katlibs/shared/")

include("katlibs/universal/preload/kerror.lua")
include("katlibs/universal/preload/kclass.lua")
include("katlibs/universal/preload/kautoloader.lua")

KAutoLoader.IncludeDir("katlibs/universal/",{Realm = "sh",Recursive = false})
KAutoLoader.IncludeDir("katlibs/shared/",{Realm = "sh",Recursive = false})
KAutoLoader.IncludeDir("katlibs/client/",{Realm = "cl",Recursive = false})
KAutoLoader.IncludeDir("katlibs/server/",{Realm = "sv",Recursive = false})

MsgC(Color(255,0,0),"[katlibs]",Color(255,255,255)," Initialized.")
hook.Run("KatLibsLoaded")