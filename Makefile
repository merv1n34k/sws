.PHONY: setup dev build test test-all lint fmt clean run install

setup:
	swift package resolve

dev:
	swift build && .build/debug/sws

build:
	swift build -c release

test:
	swift test

test-all:
	swift test

lint:
	@which swiftlint >/dev/null 2>&1 && swiftlint lint --quiet || echo "swiftlint not installed, skipping"

fmt:
	@which swiftformat >/dev/null 2>&1 && swiftformat Sources/ || echo "swiftformat not installed, skipping"

clean:
	swift package clean
	rm -rf .build/

run:
	swift build -c release && .build/release/sws

install: build
	cp .build/release/sws /usr/local/bin/sws
