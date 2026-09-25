.PHONY: build test check bundle release bench-test clean

build:
	swift build --product Mote

test:
	swift test

check: test
	./scripts/test-product-identity.sh
	./scripts/test-bundle-security.sh

bundle:
	./scripts/bundle.sh

release:
	./scripts/release.sh

bench-test:
	./Tools/Bench/test.sh

clean:
	swift package clean
