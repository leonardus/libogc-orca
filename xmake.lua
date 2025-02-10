set_project("ogc")
set_version("2.1.0")
local DIRNAME = "libogc-orca"

-- Suppreses xmake compiler check which can take some time
set_defaultarchs("ppc")
set_defaultplat("dolphin")

toolchain("devkitppc")
	set_kind("standalone")
	on_check(function()
		return os.isdir("$(env DEVKITPRO)") and os.isdir("$(env DEVKITPPC)")
	end)
	set_bindir("$(env DEVKITPPC)/bin")
	set_toolset("cc", "powerpc-eabi-gcc")
	set_toolset("ld", "powerpc-eabi-gcc")
	set_toolset("ar", "powerpc-eabi-ar")
	set_toolset("strip", "powerpc-eabi-strip")
	set_toolset("as", "powerpc-eabi-gcc")
toolchain_end()

local libraries = {
	ogc = {
		sources = {"libogc/*.c", "libogc/*.S"},
		platforms = {"cube", "wii"}
	},
	iso9660 = {
		sources = {"libiso9660/iso9660.c"},
		platforms = {"cube", "wii"}
	}
}

target("headers")
	set_kind("phony")
	set_toolchains("devkitppc")
	set_installdir(path.join("$(env DEVKITPRO)", DIRNAME))
	set_prefixdir("include")
	add_installfiles("gc/*.h", "gc/(bte/*.h)", "gc/(di/*.h)", "gc/(modplay/*.h)",
	"gc/(ogc/*.h)", "gc/(ogc/machine/*.h)", "gc/(sdcard/*.h)", "gc/(sys/*.h)",
	"gc/(wiikeyboard/*.h)", "gc/(wiiuse/*.h)")

	on_load(function(target)
		local function trimcmd(s) return string.gsub(os.iorun(s), "[\r\n]", "") end
		target:set("configdir", "gc/ogc")
		target:add("configfiles", "gc/ogc/libversion.h.in", {variables={
			DATE = trimcmd("git log -1 --format=%cd --date=format-local:\"%b %e %Y\""),
			TIME = trimcmd("git log -1 --format=%cd --date=format-local:\"%H:%M:%S\""),
			VERSTRING = format(
				"r%s.%s",
				trimcmd("git rev-list --count HEAD"),
				trimcmd("git rev-parse --short=7 HEAD")
			),
			REVISION = trimcmd("git rev-list --count HEAD")
		}})
	end)

	before_install(function(target)
		os.mkdir(path.join(target:get("installdir"), "include"))
	end)
target_end()

for basename, lib in pairs(libraries) do
	for _, plat in pairs(lib.platforms) do
		target(plat .. "/" .. basename)
			set_kind("static")
			set_toolchains("devkitppc")
			set_arch("ppc")
			set_plat(({cube="dolphin", wii="revolution"})[plat])
			add_deps("headers")

			set_prefixname("lib")
			set_basename(basename)
			set_suffixname("")
			set_extension(".a")
			set_installdir(path.join("$(env DEVKITPRO)", DIRNAME))
			set_prefixdir("/", {libdir = path.join("lib", plat)})

			add_includedirs("$(projectdir)", "gc", "gc/netif", "gc/ipv4", "gc/ogc",
				"gc/ogc/machine", "gc/modplay", "gc/bte", "gc/sdcard", "gc/wiiuse", "gc/di",
				"$(env DEVKITPRO)/portlibs/ppc/include")
			add_defines("BIGENDIAN", "GEKKO", "LIBOGC_INTERNAL")
			add_defines(({cube="HW_DOL", wii="HW_RVL"})[plat])
			add_cflags("-mcpu=750", "-meabi", "-msdata=eabi", "-mhard-float",
				"-ffunction-sections", "-fdata-sections", "-fno-strict-aliasing",
				"-Wno-address-of-packed-member", {force=true})
			add_cflags(({cube="-Wa,-mgekko", wii="-Wa,-mbroadway"})[plat], {force=true})
			add_asflags("-mregnames", "-D_LANGUAGE_ASSEMBLY")
			add_asflags(({cube="-Wa,-mgekko", wii="-Wa,-mbroadway"})[plat], {force=true})
			set_symbols("debug")
			set_optimize("faster")
			set_warnings("all")

			add_files(table.unpack(lib.sources))

			before_install(function(target)
				os.mkdir(path.join(target:get("installdir"), "lib", plat))
			end)
		target_end()
	end
end
