GREP=^        [\[-]
SED=s/^\s*-- \(.*\) \(http.*\)/\n\#\#\# \1: ([\2]](\2))\n|alias|full name|\n|-|-|/; s/^\s*\[/|/; s/|http/\n[http/g; s/\]//; s/"//g; s/=/|/g; s/,\s*$$/ |/
AWK_1=-v 'p=1' 'p;/<!--splitter-->/{p=0}'

make: README.md Aliases.lua
	cp README.md README.md.copy && \
	awk $(AWK_1) README.md.copy > README.md && \
	rm README.md.copy && \
	grep '$(GREP)' Aliases.lua | sed '$(SED)' >> README.md

