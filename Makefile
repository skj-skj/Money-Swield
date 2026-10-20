# Development shortcuts. Run `make` (or `make help`) to list them.
#
# FILES picks the files or folders for format, analyze and test; leave it
# out to run on the whole project:
#   make format FILES="lib/ui/core/picker_order.dart test/ui/core"
#   make test FILES=test/ui/core/picker_order_test.dart
#
# A full `make test` runs the generated suites (tool/test_suites.dart): the
# same tests, compiled as two files instead of one per test file.

# Bash on every OS. Without this, make on Windows may run recipes in
# cmd.exe, where the shell syntax below fails. A full path, not `bash`:
# from PowerShell, `bash` on PATH can be Windows' WSL launcher
# (System32\bash.exe), which runs recipes in Linux, where Windows tools such
# as act.exe are not found by their plain name. /bin/bash is make's own
# MSYS / Git Bash on Windows, and the system bash on Linux and macOS.
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

# The flutter script starts with `#!/usr/bin/env bash`. Run from PowerShell,
# PATH has System32 (WSL's bash.exe) before MSYS's /usr/bin, so env starts
# WSL, which can't find C:/flutter/bin/flutter. Put /usr/bin first so env
# finds MSYS's bash.
ifeq ($(OS),Windows_NT)
export PATH := /usr/bin:$(PATH)
endif

FILES ?=
# debug or release.
MODE ?= debug
# foss (F-Droid, the FOSS APK) or play (Google Play).
FLAVOR ?= foss
# Debug builds only: how many days back the SMS scan reads and the purge keeps,
# for a test phone whose SMS are old. Release builds ignore it.
SMS_LOOKBACK_DAYS ?=
# NO_SMS=1 builds play without READ_SMS.
NO_SMS ?=
# Name for `make migration`, in snake_case.
NAME ?=

# Each flavor has its own id (owner, 2026-10-11: `.foss` / `.play`), and a
# debug (and profile) build adds `.debug` so it never touches a released
# app's data (owner, 2026-10-12).
APP_ID := com.skj.money.swield.expense.tracker.$(FLAVOR)$(if $(filter debug profile,$(MODE)),.debug)
# Flutter names flavored APKs app-<flavor>-<mode>.apk.
APK := build/app/outputs/flutter-apk/app-$(FLAVOR)-$(MODE).apk
DART_DEFINES := $(if $(SMS_LOOKBACK_DAYS),--dart-define=SMS_LOOKBACK_DAYS=$(SMS_LOOKBACK_DAYS))
GRADLE_ARGS := $(if $(NO_SMS),-PnoSms=true)
# Release builds use neither --split-debug-info nor --obfuscate: together
# they save only ~0.7 MB per APK, and would make release stack traces
# unreadable without symbol files kept per release (owner, 2026-10-14).
# Release builds for upload. `--split-per-abi` makes one APK per ABI
# (armeabi-v7a, arm64-v8a, x86_64), each with version code
# `build number * 10 + ABI number` (android/app/build.gradle.kts), so they
# never clash.
VERSION := $(shell sed -n 's/^version: *\([^+]*\).*/\1/p' pubspec.yaml)
DIST := build/dist
ABIS := armeabi-v7a arm64-v8a x86_64

.DEFAULT_GOAL := help
.PHONY: help format analyze test test-android build bundle github fdroid install uninstall reinstall migration check-dep require-key release release-check release-signing release-notes release-publish release-act

help:
	@echo 'make format    [FILES=...]   dart format (whole project by default)'
	@echo 'make analyze   [FILES=...]   flutter analyze'
	@echo 'make test      [FILES=...]   flutter test (full run: two suites)'
	@echo 'make test-android            JVM unit tests of the Kotlin code (gradle)'
	@echo 'make build     [MODE=debug|release] [FLAVOR=foss|play] [SMS_LOOKBACK_DAYS=n]  build the APK'
	@echo 'make bundle    [NO_SMS=1]    Google Play: the play AAB (release, needs android/key.properties)'
	@echo 'make github    [NO_SMS=1]    GitHub: foss + play release APKs split per ABI (6) in $(DIST)/'
	@echo 'make fdroid                  F-Droid check: foss release APKs split per ABI (3) in $(DIST)/'
	@echo 'make release                 GitHub release from HEAD: check, build, tag, publish (needs gh)'
	@echo 'make release-check           is pubspec.yaml a new version, with its changelog?'
	@echo 'make release-notes           write $(DIST)/release-notes.md from the changelog'
	@echo 'make release-act             run the release workflow locally in Docker (act), as a dry run'
	@echo 'make install   [MODE=...] [FLAVOR=...]  install the built APK over adb'
	@echo 'make uninstall               uninstall the app (deletes its data)'
	@echo 'make reinstall [MODE=...] [FLAVOR=...]  uninstall, then install (fresh data)'
	@echo 'make migration NAME=snake_case_name  create a database migration'
	@echo 'make check-dep               report outdated Flutter and Android (Gradle) dependencies'

# The page width comes from analysis_options.yaml, so it isn't passed here.
format:
	dart format $(or $(FILES),lib test tool)

analyze:
	flutter analyze $(FILES)

test:
ifeq ($(FILES),)
	dart tool/test_suites.dart
	flutter test test_suites
else
	flutter test $(FILES)
endif

# The JDK Flutter builds with (Android Studio's), read from flutter doctor
# only when this target runs; pass ANDROID_JDK=... to use another. A
# JAVA_HOME left pointing at an old JDK would otherwise fail gradle.
ANDROID_JDK ?= $(shell flutter doctor -v 2>/dev/null | sed -n 's/.*Java binary at: \(.*\)[\/]bin[\/]java.*/\1/p')

test-android:
	@test -n '$(ANDROID_JDK)' || { echo 'No JDK found: pass ANDROID_JDK=<jdk folder>'; exit 1; }
	cd android && JAVA_HOME='$(ANDROID_JDK)' ./gradlew :app:testFossDebugUnitTest :app:testPlayDebugUnitTest

build:
	flutter build apk --$(MODE) --flavor $(FLAVOR) $(DART_DEFINES) $(GRADLE_ARGS)

# Upload builds must be signed with the release key; without
# android/key.properties gradle falls back to the debug key.
require-key:
	@test -f android/key.properties || { echo 'android/key.properties not found: release uploads need the release key'; exit 1; }

bundle: require-key
	flutter build appbundle --release --flavor play $(GRADLE_ARGS)
	@echo 'AAB: build/app/outputs/bundle/playRelease/app-play-release.aab'

# Builds one flavor's release APKs split per ABI and copies them to
# $(DIST)/money-swield-<version>-<flavor>-<abi>.apk. github and fdroid
# empty $(DIST) first, so it holds only what to upload.
define split_apks
	flutter build apk --release --split-per-abi --flavor $(1) $(GRADLE_ARGS)
	mkdir -p $(DIST)
	for abi in $(ABIS); do \
	  cp build/app/outputs/flutter-apk/app-$$abi-$(1)-release.apk \
	    $(DIST)/money-swield-$(VERSION)-$(1)-$$abi.apk; \
	done
endef

github: require-key
	rm -rf $(DIST)
	$(call split_apks,foss)
	$(call split_apks,play)
	@ls -1 $(DIST)

# F-Droid builds from source with its own recipe (fdroiddata) and, when its
# build matches the GitHub release, publishes our signed APKs. This builds
# the foss APKs locally (no release key needed), to check them before
# tagging; they won't match byte for byte (see .github/workflows/release.yml).
fdroid:
	rm -rf $(DIST)
	$(call split_apks,foss)
	@ls -1 $(DIST)

# Installs what `make build` produced; it doesn't rebuild. -r keeps the app
# data. Set ANDROID_SERIAL when several devices are connected.
install:
	@test -f $(APK) || { echo '$(APK) not found: run make build MODE=$(MODE) FLAVOR=$(FLAVOR) first'; exit 1; }
	adb install -r $(APK)

# Android deletes the app's data with it, database included.
uninstall:
	adb uninstall $(APP_ID)

# Checks the APK before uninstalling, so a missing build doesn't leave the
# phone without the app. `|| true` lets it run when the app isn't installed
# yet; a missing device still fails at the install step.
reinstall:
	@test -f $(APK) || { echo '$(APK) not found: run make build MODE=$(MODE) FLAVOR=$(FLAVOR) first'; exit 1; }
	adb uninstall $(APP_ID) || true
	adb install $(APK)

migration:
	@test -n '$(NAME)' || { echo 'Usage: make migration NAME=add_currency_to_expenses'; exit 1; }
	dart tool/new_migration.dart $(NAME)

# Reports only; updating stays a deliberate step. pub outdated covers the
# Dart packages; Gradle has no such command, so the init script adds the
# Gradle Versions Plugin for this run only (the wrapper, plugins and Kotlin
# libraries). Gradle needs the JDK, like test-android.
check-dep:
	flutter pub outdated
	@test -n '$(ANDROID_JDK)' || { echo 'No JDK found: pass ANDROID_JDK=<jdk folder>'; exit 1; }
	cd android && JAVA_HOME='$(ANDROID_JDK)' ./gradlew -I ../tool/check_dep.init.gradle.kts dependencyUpdates

# Releases: scripts/release.py does the work; .github/workflows/release.yml
# runs the same targets. On Windows `python3` may be the Microsoft Store
# stub, so plain `python` is used there.
PYTHON ?= $(if $(filter Windows_NT,$(OS)),python,python3)

# The version is checked first, so nothing is built for a version that
# can't be released.
release: release-check require-key
	$(MAKE) github
	$(MAKE) release-notes
	$(MAKE) release-publish

release-check:
	$(PYTHON) scripts/release.py check

# CI only: writes android/key.properties from the ANDROID_* environment
# variables (see the workflow). Refuses to replace an existing one.
release-signing:
	$(PYTHON) scripts/release.py signing

release-notes:
	$(PYTHON) scripts/release.py notes

release-publish:
	$(PYTHON) scripts/release.py publish

# Runs the workflow in Docker with act (https://github.com/nektos/act), as a
# dry run: the APKs land in build/act-artifacts, nothing is tagged. The
# release key comes from .secrets (gitignored), in the workflow's names:
#   ANDROID_KEYSTORE_BASE64=<base64 of the .jks, one line>
#   ANDROID_STORE_PASSWORD=...  ANDROID_KEY_ALIAS=...  ANDROID_KEY_PASSWORD=...
# The full image has the Android SDK the build needs (a large download).
# --pull=false uses the local copy instead of pulling the image on every run
# (act's default); update it by hand with
# `docker pull catthehacker/ubuntu:full-latest`. --rm removes the job
# container when a run fails or is stopped, so the next run doesn't fail on
# "volume is in use".
release-act:
	@test -f .secrets || { echo '.secrets not found: see the comment above release-act in the Makefile'; exit 1; }
	act workflow_dispatch -W .github/workflows/release.yml \
	  --input dry_run=true --secret-file .secrets \
	  --artifact-server-path build/act-artifacts \
	  -P ubuntu-latest=catthehacker/ubuntu:full-latest \
	  --pull=false --rm
