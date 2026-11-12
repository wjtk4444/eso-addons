# Regenerates the alias tables at the end of README.md (everything after the
# <!--splitter--> line) from Aliases.lua and tools/instances.txt.
# Needs Lua 5.1 or LuaJIT: make LUA=luajit

LUA ?= lua5.1

readme: README.md Aliases.lua Helpers.lua tools/instances.txt tools/readme_aliases.lua
	awk '{ print } /<!--splitter-->/ { exit }' README.md > README.md.tmp
	$(LUA) tools/readme_aliases.lua >> README.md.tmp
	mv README.md.tmp README.md

.PHONY: readme
