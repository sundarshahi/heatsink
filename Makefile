SHELL := /bin/bash
PREFIX ?= $(HOME)/.local

test:
	bats tests/

lint:
	shellcheck -x bin/heatsink $(wildcard lib/*.sh) $(wildcard adapters/*/hook.sh)

# README images. Needs charmbracelet/freeze. The process table and load are the
# test fixtures, so the shots are reproducible on any machine, hot or idle.
screenshots: export PATH := $(CURDIR)/bin:$(PATH)
screenshots: export HEATSINK_FAKE_PS := $(CURDIR)/tests/fixtures/ps-orphans.txt
screenshots: export HEATSINK_TEST_USER := dev
screenshots: export HEATSINK_FAKE_CORES := 10
screenshots:
	mkdir -p docs/img
	HEATSINK_FAKE_LOAD=99 freeze -x "heatsink doctor" --window -o docs/img/doctor.png
	HEATSINK_FAKE_LOAD=99 freeze -x "heatsink reap"   --window -o docs/img/reap.png
	freeze -x "bash tests/demo-verdicts.sh" --window -o docs/img/check.png

install:
	mkdir -p $(PREFIX)/bin $(PREFIX)/share/heatsink/bin
	cp -R lib adapters $(PREFIX)/share/heatsink/
	install -m 0755 bin/heatsink $(PREFIX)/share/heatsink/bin/heatsink
	ln -sf $(PREFIX)/share/heatsink/bin/heatsink $(PREFIX)/bin/heatsink

.PHONY: test lint install screenshots
