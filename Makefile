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
# cmd.exe, where the shell syntax below fails.
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c

FILES ?=
# debug or release.
MODE ?= debug
# Name for `make migration`, in snake_case.
NAME ?=

APP_ID := com.skj.expense.tracker.my_expense_tracker_app
APK := build/app/outputs/flutter-apk/app-$(MODE).apk

.DEFAULT_GOAL := help
.PHONY: help format analyze test test-android build install uninstall reinstall migration

help:
	@echo 'make format    [FILES=...]   dart format (whole project by default)'
	@echo 'make analyze   [FILES=...]   flutter analyze'
	@echo 'make test      [FILES=...]   flutter test (full run: two suites)'
	@echo 'make test-android            JVM unit tests of the Kotlin code (gradle)'
	@echo 'make build     [MODE=debug|release]  build the APK'
	@echo 'make install   [MODE=debug|release]  install the built APK over adb'
	@echo 'make uninstall               uninstall the app (deletes its data)'
	@echo 'make reinstall [MODE=debug|release]  uninstall, then install (fresh data)'
	@echo 'make migration NAME=snake_case_name  create a database migration'

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
	cd android && JAVA_HOME='$(ANDROID_JDK)' ./gradlew :app:testDebugUnitTest

build:
	flutter build apk --$(MODE)

# Installs what `make build` produced; it doesn't rebuild. -r keeps the app
# data. Set ANDROID_SERIAL when several devices are connected.
install:
	@test -f $(APK) || { echo '$(APK) not found: run make build MODE=$(MODE) first'; exit 1; }
	adb install -r $(APK)

# Android deletes the app's data with it, database included.
uninstall:
	adb uninstall $(APP_ID)

# Checks the APK before uninstalling, so a missing build doesn't leave the
# phone without the app. `|| true` lets it run when the app isn't installed
# yet; a missing device still fails at the install step.
reinstall:
	@test -f $(APK) || { echo '$(APK) not found: run make build MODE=$(MODE) first'; exit 1; }
	adb uninstall $(APP_ID) || true
	adb install $(APK)

migration:
	@test -n '$(NAME)' || { echo 'Usage: make migration NAME=add_currency_to_expenses'; exit 1; }
	dart tool/new_migration.dart $(NAME)
