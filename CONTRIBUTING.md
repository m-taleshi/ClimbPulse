<![CDATA[# Contributing to ClimbPulse

Thank you for your interest in contributing to ClimbPulse! We welcome contributions from the community.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How to Contribute](#how-to-contribute)
- [Development Guidelines](#development-guidelines)
- [Pull Request Process](#pull-request-process)

## 📜 Code of Conduct

This project adheres to a code of conduct. By participating, you are expected to uphold this code. Please report unacceptable behavior to the project maintainers.

## 🚀 Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/ClimbPulse.git
   cd ClimbPulse
   ```
3. **Open in Xcode**:
   ```bash
   open ClimbPulse.xcodeproj
   ```
4. **Configure signing** with your Apple Developer account
5. **Build and run** to ensure everything works

## 🤝 How to Contribute

### Reporting Bugs

- Use the GitHub Issues page
- Include iOS version, device model, and steps to reproduce
- Attach relevant logs or screenshots if available

### Suggesting Features

- Open an issue with the "enhancement" label
- Describe the feature and its use case
- Discuss implementation approach if you have ideas

### Code Contributions

1. Check existing issues for something to work on
2. Comment on the issue to claim it
3. Create a feature branch
4. Make your changes
5. Submit a pull request

## 💻 Development Guidelines

### Code Style

- Follow Swift API Design Guidelines
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions focused and concise

### SwiftUI Best Practices

- Use `@State` for local view state
- Use `@StateObject` for view-owned ObservableObjects
- Use `@EnvironmentObject` for shared state
- Extract reusable components

### Signal Processing

When modifying PPG processing:
- Document algorithm changes with references
- Test with real measurements on multiple devices
- Consider edge cases (motion artifacts, ambient light)

### Testing

- Test on real devices (camera features don't work in simulator)
- Test in both light and dark mode
- Test with different finger placements and lighting conditions

## 📝 Pull Request Process

1. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** with clear, atomic commits

3. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

4. **Open a Pull Request** with:
   - Clear title describing the change
   - Description of what and why
   - Reference to any related issues
   - Screenshots for UI changes

5. **Address review feedback** and update the PR

6. **Merge** once approved

## 📁 Project Structure

```
ClimbPulse/
├── API/          # Backend integration
├── Capture/      # Camera and signal processing
├── Models/       # Data models
├── Storage/      # Local persistence
└── Views/        # SwiftUI views and components
```

## 🆘 Need Help?

- Open an issue for questions
- Check existing issues for similar topics
- Review the README for general information

Thank you for contributing to ClimbPulse! 🎉
]]>
