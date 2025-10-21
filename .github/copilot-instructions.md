# GitHub Copilot Instructions for Linux DevTools Installation Script

## Project Overview
This is an enhanced Linux development tools installation script that supports both Debian-based (Ubuntu, Debian, Linux Mint, Pop!_OS) and Arch-based (Arch Linux, Manjaro, EndeavourOS) distributions.

## Key Principles

### Error Handling
- **try to always use `set -e` except that is not convinient for the command** - in some cases the script should continue even if individual installations fail

### MD files

- Be really precise with the usage of .md files.
- DO NOT Create .md files summarizing the changes. Just explain as an output in the console to me. 
- Only create summary .md files if explicitly stated.