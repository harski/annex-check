
prefix=/usr/local
bindir=$(prefix)/bin
install=install

target=annex-check

all:
	@echo "Nothing to build"

install:
	$(install) annex-check.pl $(bindir)/$(target)

uninstall:
	rm $(bindir)/$(target)

