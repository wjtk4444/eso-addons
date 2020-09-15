GREP=^        [\[-]

SED=s/^\s*-- \(.*\) \(http.*\)/\n\#\#\# \1: ([\2]](\2))\n|alias|full name|\n|-|-|/; s/^\s*\[/|/; s/|http/\n[http/g; s/\]//; s/"//g; s/=/|/g; s/,\s*$$/|/

make: readme-template.md Aliases.lua
	cat readme-template.md > README.md && \
	grep '$(GREP)' Aliases.lua | sed '$(SED)' >> README.md
