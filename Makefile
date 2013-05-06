
prefix=/usr/local
bindir=$(prefix)/bin
mandir=$(prefix)/share/man
mancat=1
install=install

target=annex-check

all:
	@echo "Nothing to build"

install: install-bin install-man

install-bin:
	@mkdir -p $(bindir)
	$(install) $(target).pl $(bindir)/$(target)
	@chmod 0755 $(bindir)/$(target)

install-man:
	@mkdir -p $(mandir)/man$(mancat)
	$(install) $(target).$(mancat) $(mandir)/man$(mancat)/$(target).$(mancat)
	@chmod 0444 $(mandir)/man$(mancat)/$(target).$(mancat)

uninstall:
	rm $(bindir)/$(target)

