
prefix=/usr/local
bindir=$(prefix)/bin
install=install


all:
	@echo "Nothing to build"

install:
	$(install) annex-check.pl $(bindir)/annex-check

