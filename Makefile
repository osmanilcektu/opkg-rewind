VERSION ?= 0.1.1-1
BUILD := build
PKGROOT := $(BUILD)/data
CONTROL := $(BUILD)/control
IPK := $(BUILD)/opkg-rewind_$(VERSION)_all.ipk

.PHONY: all clean test ipk

all: test ipk

clean:
	rm -rf $(BUILD)

# Uses only host build tools; runtime target remains dependency-free.
test:
	sh -n src/rewind
	busybox ash -n src/rewind
	sh tests/run.sh

ipk: clean
	mkdir -p $(PKGROOT)/opt/bin $(PKGROOT)/opt/etc $(PKGROOT)/opt/var/lib/opkg-rewind/transactions $(PKGROOT)/opt/share/licenses/opkg-rewind $(CONTROL)
	cp src/rewind $(PKGROOT)/opt/bin/rewind
	chmod 0755 $(PKGROOT)/opt/bin/rewind
	ln -sf rewind $(PKGROOT)/opt/bin/opkg-rewind
	cp packaging/opkg-rewind.conf $(PKGROOT)/opt/etc/opkg-rewind.conf
	cp LICENSE $(PKGROOT)/opt/share/licenses/opkg-rewind/LICENSE
	cp packaging/control $(CONTROL)/control
	cp packaging/conffiles $(CONTROL)/conffiles
	( cd $(PKGROOT) && tar -czf ../data.tar.gz . )
	installed_size="$$(gzip -cd $(BUILD)/data.tar.gz | wc -c | tr -d ' ')"; \
		sed -i "s/^Installed-Size: .*/Installed-Size: $$installed_size/" $(CONTROL)/control
	( cd $(CONTROL) && tar -czf ../control.tar.gz ./control ./conffiles )
	printf '2.0\n' > $(BUILD)/debian-binary
	( cd $(BUILD) && tar -czf "$$(basename $(IPK))" ./debian-binary ./data.tar.gz ./control.tar.gz )
	@echo "Built $(IPK)"
