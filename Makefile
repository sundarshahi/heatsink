SHELL := /bin/bash
PREFIX ?= $(HOME)/.local

test:
	bats tests/

lint:
	shellcheck -x bin/heatsink $(wildcard lib/*.sh) $(wildcard adapters/*/hook.sh)

install:
	mkdir -p $(PREFIX)/bin $(PREFIX)/share/heatsink/bin
	cp -R lib adapters $(PREFIX)/share/heatsink/
	install -m 0755 bin/heatsink $(PREFIX)/share/heatsink/bin/heatsink
	ln -sf $(PREFIX)/share/heatsink/bin/heatsink $(PREFIX)/bin/heatsink

.PHONY: test lint install
