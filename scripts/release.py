"""Release helper, shared by `make release*` and the GitHub release workflow.

    python scripts/release.py check     version and changelog checks
    python scripts/release.py signing   writes android/key.properties and
                                        the keystore from environment
                                        variables (CI)
    python scripts/release.py notes     writes build/dist/release-notes.md
    python scripts/release.py publish   finalizes CHANGELOG.md, tags, pushes
                                        and publishes the GitHub release
                                        with build/dist/*.apk

The version lives in pubspec.yaml (`version: 1.2.3+4`). A release tag is
`v<version name>` (`v1.2.3`), the tag F-Droid's recipe watches.

CHANGELOG.md has one section per version, newest first. The top one is
the next release, marked unreleased, and gathers its changes as they are
made:

    ## 1.2.3 (Unreleased)

    - Fixed ...

    ## 1.2.2

    - ...

`publish` makes two commits on the current branch:

1. "release 1.2.3": drops "(Unreleased)" and writes the section to
   F-Droid's changelog files (fastlane/metadata/android/en-US/changelogs/
   <1000+N|2000+N|4000+N>.txt, one per split-APK version code). This
   commit gets the tag, so F-Droid reads the listing from it.
2. "start 1.2.4": adds an empty `## 1.2.4 (Unreleased)` section on top.
   The next patch version is a guess; edit the heading for a minor or
   major release.

Standard library only; needs git, and gh (GitHub CLI) for `publish`.
"""

import base64
import binascii
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PUBSPEC = ROOT / "pubspec.yaml"
CHANGELOG = ROOT / "CHANGELOG.md"
FDROID_CHANGELOGS = ROOT / "fastlane/metadata/android/en-US/changelogs"
DIST = ROOT / "build/dist"
NOTES = DIST / "release-notes.md"

# Flutter's --split-per-abi adds 1000 * ABI number to the build number:
# armeabi-v7a 1, arm64-v8a 2, x86_64 4.
ABI_OFFSETS = (1000, 2000, 4000)
ABIS = ("armeabi-v7a", "arm64-v8a", "x86_64")
FLAVORS = ("foss", "play")
# F-Droid's limit for a changelog file.
FDROID_MAX_CHARS = 500
# The build number must stay below 1000, or a split APK's version code
# would clash with the next ABI's (1000 + 1001 == 2000 + 1).
BUILD_NUMBER_MAX = 999
UNRELEASED = "(Unreleased)"

VERSION_RE = re.compile(
    r"^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$", re.MULTILINE
)
TAG_RE = re.compile(r"^v(\d+)\.(\d+)\.(\d+)$")
# The lookahead stops before a "\r": with core.autocrlf, Windows checkouts
# have CRLF line endings, and a match that ate the "\r" would lose it when
# the heading is rewritten.
SECTION_RE = re.compile(
    r"^## (\d+)\.(\d+)\.(\d+)( \(Unreleased\))?[ \t]*(?=\r?$)",
    re.MULTILINE,
)


class ReleaseError(Exception):
    pass


def git(*args):
    result = subprocess.run(
        ["git", *args],
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    if result.returncode != 0:
        raise ReleaseError(
            f"git {' '.join(args)} failed:\n{result.stderr.strip()}"
        )
    return result.stdout


def parse_version(pubspec_text, where):
    match = VERSION_RE.search(pubspec_text)
    if not match:
        raise ReleaseError(
            f"{where}: no `version: <major>.<minor>.<patch>+<build>` line"
        )
    major, minor, patch, build = (int(g) for g in match.groups())
    return (major, minor, patch), build


def name_of(version):
    return ".".join(str(part) for part in version)


def current_version():
    return parse_version(PUBSPEC.read_text(encoding="utf-8"), "pubspec.yaml")


def previous_release():
    """The highest `vX.Y.Z` tag with its pubspec version, or None."""
    tags = []
    for tag in git("tag", "--list", "v*").split():
        match = TAG_RE.match(tag)
        if match:
            tags.append((tuple(int(g) for g in match.groups()), tag))
    if not tags:
        return None
    _, tag = max(tags)
    version, build = parse_version(
        git("show", f"{tag}:pubspec.yaml"), f"pubspec.yaml at {tag}"
    )
    return tag, version, build


def remote_tag_exists(tag):
    return bool(
        git("ls-remote", "--tags", "origin", f"refs/tags/{tag}").strip()
    )


def read_changelog():
    # newline="" keeps the file's own line endings when it is written back.
    with open(CHANGELOG, encoding="utf-8", newline="") as file:
        return file.read()


def write_changelog(text):
    with open(CHANGELOG, "w", encoding="utf-8", newline="") as file:
        file.write(text)


def top_section(text):
    """(heading match, body) of the newest section in CHANGELOG.md."""
    headings = list(SECTION_RE.finditer(text))
    if not headings:
        raise ReleaseError(
            "CHANGELOG.md has no `## x.y.z (Unreleased)` section"
        )
    for later in headings[1:]:
        if later.group(4):
            raise ReleaseError(
                f"CHANGELOG.md: only the top section can be unreleased, "
                f"not {later.group(0).strip()!r}"
            )
    first = headings[0]
    end = headings[1].start() if len(headings) > 1 else len(text)
    # Plain "\n" for the F-Droid files and release notes, whatever the
    # checkout's line endings.
    body = text[first.end() : end].replace("\r\n", "\n").strip()
    return first, body


def unreleased_changes(version):
    """The body of the top section, which must be `version (Unreleased)`."""
    heading, body = top_section(read_changelog())
    section_version = tuple(int(g) for g in heading.group(1, 2, 3))
    if not heading.group(4):
        raise ReleaseError(
            f"CHANGELOG.md: the top section {name_of(section_version)} is "
            f"already released; add `## {name_of(version)} {UNRELEASED}`"
        )
    if section_version != version:
        raise ReleaseError(
            f"CHANGELOG.md's next version is {name_of(section_version)} but "
            f"pubspec.yaml's is {name_of(version)}: make them the same"
        )
    if not body:
        raise ReleaseError(
            f"CHANGELOG.md: no changes listed under {name_of(version)}"
        )
    if len(body) > FDROID_MAX_CHARS:
        raise ReleaseError(
            f"CHANGELOG.md: the {name_of(version)} changes are {len(body)} "
            f"characters; F-Droid allows {FDROID_MAX_CHARS}"
        )
    return body


def check():
    """Fails unless this commit is a new, complete release."""
    version, build = current_version()
    tag = f"v{name_of(version)}"
    print(f"pubspec.yaml version: {name_of(version)}+{build}")

    if not 1 <= build <= BUILD_NUMBER_MAX:
        raise ReleaseError(
            f"build number {build} must be between 1 and {BUILD_NUMBER_MAX}"
        )

    # The version check comes first: a release that reuses a version
    # would be refused by every phone that has the old one.
    previous = previous_release()
    if previous is None:
        print("previous release: none (first release)")
    else:
        prev_tag, prev_version, prev_build = previous
        print(
            f"previous release: {prev_tag} "
            f"({name_of(prev_version)}+{prev_build})"
        )
        if version <= prev_version:
            raise ReleaseError(
                f"version {name_of(version)} must be higher than "
                f"{name_of(prev_version)}: raise it in pubspec.yaml"
            )
        if build <= prev_build:
            raise ReleaseError(
                f"build number {build} must be higher than {prev_build}: "
                "raise it in pubspec.yaml"
            )
    # In CI the checkout fetched every tag; on a dev machine local tags may
    # be behind GitHub's, so GitHub is asked too.
    on_ci = os.environ.get("GITHUB_ACTIONS") == "true"
    if git("tag", "--list", tag).strip() or (
        not on_ci and remote_tag_exists(tag)
    ):
        raise ReleaseError(f"tag {tag} already exists")

    unreleased_changes(version)
    print(f"changelog: {name_of(version)} {UNRELEASED} has its changes")
    print(f"OK: ready to release {tag}")

    # Lets the workflow use the version in later steps.
    github_output = os.environ.get("GITHUB_OUTPUT")
    if github_output:
        with open(github_output, "a", encoding="utf-8") as out:
            out.write(f"tag={tag}\nversion={name_of(version)}+{build}\n")


# The release key, from the CI environment's secrets. The keystore file is
# base64 because a secret can only hold text.
SIGNING_ENV = {
    "ANDROID_KEYSTORE_BASE64": None,
    "ANDROID_STORE_PASSWORD": "storePassword",
    "ANDROID_KEY_ALIAS": "keyAlias",
    "ANDROID_KEY_PASSWORD": "keyPassword",
}
KEY_PROPERTIES = ROOT / "android/key.properties"
# Relative to android/, like storeFile in key.properties. Gitignored
# (*.p12), as is key.properties.
KEYSTORE_NAME = "release-ci.p12"


def signing():
    """Writes the release key from environment variables, for CI."""
    missing = [name for name in SIGNING_ENV if not os.environ.get(name)]
    if missing:
        raise ReleaseError(
            f"environment variables not set: {', '.join(missing)}"
        )
    # Gradle loads key.properties as ISO-8859-1.
    not_ascii = [
        name for name in SIGNING_ENV if not os.environ[name].isascii()
    ]
    if not_ascii:
        raise ReleaseError(f"not ASCII only: {', '.join(not_ascii)}")
    # Never replaces a developer's own key.properties.
    if KEY_PROPERTIES.exists():
        raise ReleaseError(
            "android/key.properties already exists; not replacing it"
        )
    try:
        keystore = base64.b64decode(
            os.environ["ANDROID_KEYSTORE_BASE64"], validate=False
        )
    except binascii.Error as error:
        raise ReleaseError(f"ANDROID_KEYSTORE_BASE64 is not base64: {error}")
    (ROOT / "android" / KEYSTORE_NAME).write_bytes(keystore)
    # java.util.Properties treats backslash as an escape; double it so a
    # password with one is read back unchanged.
    lines = [f"storeFile={KEYSTORE_NAME}"]
    for name, key in SIGNING_ENV.items():
        if key:
            value = os.environ[name].replace("\\", "\\\\")
            lines.append(f"{key}={value}")
    KEY_PROPERTIES.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"wrote android/key.properties and android/{KEYSTORE_NAME}")


def expected_apks(version):
    return [
        DIST / f"money-swield-{name_of(version)}-{flavor}-{abi}.apk"
        for flavor in FLAVORS
        for abi in ABIS
    ]


def notes():
    version, _ = current_version()
    changes = unreleased_changes(version)
    # F-Droid publishes these same foss APKs (reproducible builds, our
    # signature), so a foss install updates from either. A GitHub play APK
    # has a higher version code than Play's build, so play installs stay
    # with the source they came from.
    body = (
        f"{changes}\n\n"
        "---\n\n"
        "**Which APK?** `foss` has no closed-source code; `play` can use "
        "on-device AI to read bank SMS. Most phones need `arm64-v8a`; "
        "older 32-bit phones `armeabi-v7a`.\n\n"
        "The `foss` APKs here are the same ones F-Droid publishes, so a "
        "`foss` install can update from either. A `play` APK from here and "
        "the Google Play app can't update each other: update from where "
        "you installed it.\n"
    )
    DIST.mkdir(parents=True, exist_ok=True)
    NOTES.write_text(body, encoding="utf-8", newline="\n")
    print(f"wrote {NOTES.relative_to(ROOT)}")


def finalize_changelog(version, build):
    """Marks the top section released and writes F-Droid's files."""
    text = read_changelog()
    heading, body = top_section(text)
    released = f"## {name_of(version)}"
    write_changelog(
        text[: heading.start()] + released + text[heading.end() :]
    )
    paths = [FDROID_CHANGELOGS / f"{o + build}.txt" for o in ABI_OFFSETS]
    # Git keeps no empty folders: before the first release, a checkout has
    # no changelogs/ folder.
    FDROID_CHANGELOGS.mkdir(parents=True, exist_ok=True)
    for path in paths:
        path.write_text(body + "\n", encoding="utf-8", newline="\n")
    return [CHANGELOG, *paths]


def start_next_section(version):
    """Adds an empty `## <next patch> (Unreleased)` section on top."""
    major, minor, patch = version
    upcoming = (major, minor, patch + 1)
    text = read_changelog()
    heading, _ = top_section(text)
    newline = "\r\n" if "\r\n" in text else "\n"
    section = f"## {name_of(upcoming)} {UNRELEASED}{newline}{newline}"
    write_changelog(text[: heading.start()] + section + text[heading.start() :])
    return upcoming


def publish():
    version, build = current_version()
    name = name_of(version)
    tag = f"v{name}"
    unreleased_changes(version)

    # Checked before anything is pushed, so a missing gh can't leave a
    # pushed tag without its release.
    if shutil.which("gh") is None:
        raise ReleaseError("gh (GitHub CLI) not found: install it first")
    # Logged in too (in CI, GH_TOKEN counts): `gh release create` runs only
    # after the push.
    if subprocess.run(["gh", "auth", "status"], capture_output=True).returncode:
        raise ReleaseError("gh is not logged in: run `gh auth login` first")
    if git("status", "--porcelain").strip():
        raise ReleaseError("the working tree has changes: commit them first")
    branch = git("rev-parse", "--abbrev-ref", "HEAD").strip()
    if branch == "HEAD":
        raise ReleaseError("not on a branch: check out the release branch")
    apks = expected_apks(version)
    missing = [p.name for p in apks if not p.is_file()]
    if missing:
        raise ReleaseError(
            f"missing in build/dist: {', '.join(missing)} (run make github)"
        )
    if not NOTES.is_file():
        raise ReleaseError(
            "build/dist/release-notes.md missing (run make release-notes)"
        )

    start = git("rev-parse", "HEAD").strip()
    try:
        released_files = finalize_changelog(version, build)
        git("add", "--", *[str(p) for p in released_files])
        git("commit", "--quiet", "-m", f"chore: release {name}")
        git("tag", tag)
        upcoming = start_next_section(version)
        git("add", "--", str(CHANGELOG))
        git("commit", "--quiet", "-m", f"chore: start {name_of(upcoming)}")
        # Both commits and the tag, or nothing: a push rejected because the
        # branch moved on GitHub leaves no tag behind.
        git("push", "--atomic", "origin", f"HEAD:refs/heads/{branch}", tag)
    except BaseException:
        # Any failure, a file write or Ctrl+C included: undo the local
        # commits and tag so a rerun starts clean. The tree was clean at
        # `start`, so the reset drops only what this made, and every
        # untracked file under changelogs/ is one this wrote (the reset
        # leaves untracked files behind).
        subprocess.run(["git", "tag", "--delete", tag], cwd=ROOT,
                       capture_output=True)
        subprocess.run(["git", "reset", "--hard", "--quiet", start], cwd=ROOT)
        subprocess.run(
            ["git", "clean", "--force", "--quiet", "--",
             str(FDROID_CHANGELOGS)],
            cwd=ROOT,
        )
        raise
    print(f"pushed {branch} and {tag}")

    # The tag is on GitHub now. If this fails, rerun just this command:
    #   gh release create <tag> --verify-tag --notes-file ... <apks>
    subprocess.run(
        [
            "gh", "release", "create", tag,
            "--verify-tag",
            "--title", f"Money Swield {name}",
            "--notes-file", str(NOTES),
            *[str(p) for p in apks],
        ],
        cwd=ROOT,
        check=True,
    )
    print(f"published {tag}")


COMMANDS = {
    "check": check,
    "signing": signing,
    "notes": notes,
    "publish": publish,
}


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in COMMANDS:
        print(__doc__)
        return 2
    try:
        COMMANDS[sys.argv[1]]()
    except ReleaseError as error:
        print(f"release {sys.argv[1]}: {error}", file=sys.stderr)
        return 1
    except (subprocess.CalledProcessError, OSError) as error:
        print(f"release {sys.argv[1]}: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
