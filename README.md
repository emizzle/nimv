# `nimv`: simple nim version manager

`nimv` is a simple nim version manager, that ensures versions of nim are built
for the target platform especially with MacOS on ARM (Apple silicon).

> Unsure if your Nim is running emulated with Rossetta under ARM MacOS?
>
> Run `file $(which nim)` and if it includes "Mach-O 64-bit executable x86_64" then yes - you are running emulated.

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
Usage: nimv <command|version-tag>

Commands:
  installed      List all installed Nim versions
  available      List all available Nim versions
  current        Show current Nim version
  --version      Show nimv version
  --help         Show this help message

Parameters:
  version-tag    The Nim version to install (e.g., v2.0.14, v2.2.0)

Examples:
  /Users/egonat/repos/codex-storage/nim-codex/nimv v2.0.14     Install Nim version 2.0.14
  /Users/egonat/repos/codex-storage/nim-codex/nimv installed   List installed versions
```

## Under the hood

`nimv` clones and checkouts the nim version specified in the version-tag
parameter. It then builds said version *for the current platform target*. Then
it uses choosenim to do any symlinking needed for other tools in the ecosystem.

## Credits

The main idea was inspired by Pierre from Summarity in his post on installing
[Nim v2.0 on Apple Silicon](https://summarity.com/nim-2-m1).
