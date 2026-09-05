# Contributing to Linux DevTools Installation Script

First off, thank you for considering contributing to this project! 🎉

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the existing issues to avoid duplicates. When creating a bug report, include:

- **Distribution and version** (e.g., Ubuntu 22.04, Arch Linux)
- **Detailed description** of the problem
- **Steps to reproduce** the issue
- **Expected behavior** vs actual behavior
- **Error messages** or logs
- **Screenshots** if applicable

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, include:

- **Clear title** and description
- **Use case** for the enhancement
- **Possible implementation** approach (if you have ideas)
- **Alternative solutions** you've considered

### Pull Requests

1. **Fork the repository** and create your branch from `main`
2. **Make your changes**:
   - Follow the existing code style
   - Add comments for complex logic
   - Test on both Debian and Arch if possible
3. **Update documentation**:
   - Update README.md if adding new features
   - Add entry to CHANGELOG.md
4. **Test your changes**:
   - Test in a VM or container
   - Verify no syntax errors: `bash -n install.sh && bash -n install-ubuntu.sh && bash -n install-arch.sh`
5. **Commit your changes**:
   - Use clear commit messages
   - Reference issues when applicable
6. **Submit a pull request**

## Development Guidelines

### Code Style

- Use 4 spaces for indentation
- Add descriptive function comments
- Use meaningful variable names
- Follow existing patterns in the codebase

### Function Structure

Each installation function should:
1. Log what it's installing
2. Check distribution type
3. Install using appropriate package manager
4. Handle errors gracefully
5. Log success or warnings

Example:
```bash
install_example_tool() {
    log_info "📦 Installing Example Tool..."
    
    if [ "$DISTRO_TYPE" = "debian" ]; then
        sudo apt install -y example-tool
    elif [ "$DISTRO_TYPE" = "arch" ]; then
        sudo pacman -S --noconfirm example-tool
    fi
    
    log_success "Example Tool installed"
}
```

### Testing

Before submitting a PR:
- Test on a clean VM or container
- Verify syntax: `bash -n install.sh && bash -n install-ubuntu.sh && bash -n install-arch.sh`
- Test on both Debian and Arch if possible
- Check for idempotency (running script twice shouldn't break)

### Adding New Tools

When adding a new tool:
1. Create a new installation function
2. Add it to the `main()` function
3. Update the README.md tool list
4. Add entry to CHANGELOG.md
5. Consider both Debian and Arch installation methods

## Distribution Support

### Currently Supported
- **Debian-based**: Ubuntu, Debian, Linux Mint, Pop!_OS, Elementary OS
- **Arch-based**: Arch Linux, Manjaro, EndeavourOS, Garuda Linux

### Adding New Distributions

To add support for a new distribution family:

1. Update the `detect_distro()` function:
```bash
case $OS in
    ubuntu|debian|linuxmint|pop|elementary)
        DISTRO_TYPE="debian"
        ;;
    arch|manjaro|endeavouros|garuda)
        DISTRO_TYPE="arch"
        ;;
    fedora|rhel|centos)  # New distribution family
        DISTRO_TYPE="redhat"
        ;;
esac
```

2. Add package manager commands in each installation function
3. Test thoroughly
4. Update README.md

## Questions?

Feel free to open an issue with your question or reach out via GitHub discussions.

## Code of Conduct

- Be respectful and inclusive
- Welcome newcomers
- Focus on constructive feedback
- Help maintain a positive community

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing! 🚀
