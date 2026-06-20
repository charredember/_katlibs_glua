local function includeSH(path)
    AddCSLuaFile(path)
    include(path)
end

includeSH("katlibs/universal/preload/kerror.lua")
includeSH("katlibs/universal/preload/kclass.lua")
includeSH("katlibs/universal/preload/kautoloader.lua")

KAutoLoader.IncludeDir("katlibs/universal",{Realm = "sh",Recursive = false})
KAutoLoader.IncludeDir("katlibs/shared",{Realm = "sh",Recursive = false})
KAutoLoader.IncludeDir("katlibs/server",{Realm = "sv",Recursive = false})
KAutoLoader.IncludeDir("katlibs/client",{Realm = "cl",Recursive = false})

MsgC(Color(255,0,0),"[katlibs]",Color(255,255,255)," Initialized.")
hook.Run("KatLibsLoaded")