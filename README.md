# Assembly Calculator

A simple interactive console calculator written in x86-64 assembly language. Supports addition, subtraction, multiplication, and integer division with signed 64-bit integers.

## Features

- Four operations: `+` `-` `*` `/`
- Signed 64-bit arithmetic (handles negative numbers and large values)
- Division-by-zero and invalid-operator error handling
- Interactive loop — keeps calculating until you quit

## Building on Windows

### Prerequisites

1. **NASM** — [Download](https://www.nasm.us/pub/nasm/releasebuilds/) and add to PATH
2. **MinGW-w64** — [Download](https://www.mingw-w64.org/downloads/) (get the x86_64 variant) and add to PATH

### Assemble & Link

```cmd
nasm -f win64 calc.asm -o calc.obj
gcc calc.obj -o calc.exe -lkernel32 -nostartfiles -e main
```

### Run

```cmd
calc.exe
```

## Building on Linux

### Prerequisites

```bash
sudo apt install nasm
```

### Assemble & Link

```bash
nasm -f elf64 calc_linux.asm -o calc_linux.o
ld calc_linux.o -o calc_linux
```

### Run

```bash
./calc_linux
```

## Usage

```
================================
   Assembly Calculator v1.0
================================

Expression (e.g. 25 + 7, 100 / 4): 999999 * 999999
= 999998000001

Calculate again? (y/n): y

Expression (e.g. 25 + 7, 100 / 4): -3 * 8
= -24

Calculate again? (y/n): n
Goodbye!
```

## How It Works

The program is pure assembly — no C runtime, no external libraries. It calls OS APIs directly:

| Platform | I/O | Entry Point |
|----------|-----|-------------|
| Windows  | `WriteConsoleA` / `ReadConsoleA` (kernel32.dll) | `main` |
| Linux    | `sys_write` / `sys_read` (syscalls) | `_start` |

### Core Routines

| Routine | Purpose |
|---------|---------|
| `parse_int` | Scans ASCII digits (with optional `-`) into a signed 64-bit integer |
| `write_int` | Converts a signed 64-bit integer to ASCII and prints it |
| `skip_spaces` | Advances past whitespace in the input buffer |

## License

MIT
