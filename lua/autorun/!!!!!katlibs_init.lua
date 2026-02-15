local function includeSH(path)
    AddCSLuaFile(path)
    include(path)
end

includeSH("_katlibs_glua/universal/preload/kerror.lua")
includeSH("_katlibs_glua/universal/preload/kclass.lua")
includeSH("_katlibs_glua/universal/preload/kautoloader.lua")

KAutoLoader.IncludeDir("_katlibs_glua/universal",{Realm = "sh",Recursive = false})
KAutoLoader.IncludeDir("_katlibs_glua/shared",{Realm = "sh",Recursive = false})
KAutoLoader.IncludeDir("_katlibs_glua/server",{Realm = "sv",Recursive = false})
KAutoLoader.IncludeDir("_katlibs_glua/client",{Realm = "cl",Recursive = false})

MsgC(Color(255,0,0),"[katlibs_glua]",Color(255,255,255)," Initialized.")
hook.Run("KatLibsLoaded")