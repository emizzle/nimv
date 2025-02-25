# `nimv`: simple nim version manager

`nimv` is a simple nim version manager, that ensures versions of nim are built
for the target platform especially with MacOS on ARM (Apple silicon). [Check if
you're running `nim` on Rosetta](#rosetta-check).

## Requirements

Must be in your PATH:
- curl or wget
- git

## Installation

### On macOS/Linux

```shell
brew tap emizzle/nimv
brew install nimv
```

### On Windows

```shell
choco install nimv
```

## Usage

```shell
Usage: ./nimv.sh <command|version-tag>

Commands:
  installed      List all installed Nim versions
  available      List all available Nim versions
  current        Show current Nim version
  check          Verify correct installation and versions
  --version      Show script version
  --help         Show this help message

Parameters:
  version-tag    The Nim version to install (e.g., 2.0.14, 2.2.0)

Examples:
  ./nimv.sh 2.0.14      Install Nim version 2.0.14
  ./nimv.sh installed   List installed versions
```


## Rosetta check

If you're on macOS and using choosenim, there's a chance you're running an
emulated version of `nim`. To check, run:
```shell
file $(which nim)
```
If you're running on an emulated version (using Rosetta), you'll see something like:
```shell
/Users/foo/.nimble/bin/nim: Mach-O 64-bit executable x86_64
```
If you're running a native binary, you'll see:
```shell
/Users/foo/.nimble/bin/nim: Mach-O 64-bit executable arm64
```

This can also be done with the `check` command in `nimv`:
```shell
nimv check
✓ Checking nim binary platform matches current platform
  /usr/local/bin/nim: Mach-O 64-bit executable arm64
✓ Checking nim binary version matches nim version selected with nimv
  Version matches: 2.0.14
✓ Checking if nimv has available updates
  Currently up-to-date: 0.0.4
```
The first two lines of the output indicate which binary nim has been compiled
for and that it matches the platform of the current machine.

## Under the hood

`nimv` clones and checkouts the nim version specified in the version-tag
parameter. It then builds said version *for the current platform target*. Then
it uses choosenim to do any symlinking needed for other tools in the ecosystem.

## Credits

The main idea was inspired by Pierre from Summarity in his post on installing
[Nim v2.0 on Apple Silicon](https://summarity.com/nim-2-m1).