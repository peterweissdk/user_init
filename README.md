# 💾 User Init

[![Static Badge](https://img.shields.io/badge/Linux-Debian-white?style=flat&logo=debian&logoColor=white&logoSize=auto&labelColor=black)](https://www.linux.org/)
[![Static Badge](https://img.shields.io/badge/Linux-Alpine-white?style=flat&logo=alpinelinux&logoColor=white&logoSize=auto&labelColor=black)](https://www.linux.org/)
[![Static Badge](https://img.shields.io/badge/Bash-script-white?style=flat&logo=gnubash&logoColor=white&logoSize=auto&labelColor=black)](https://www.gnu.org/software/bash/)
[![Static Badge](https://img.shields.io/badge/GPL-V3-white?style=flat&logo=gnu&logoColor=white&logoSize=auto&labelColor=black)](https://www.gnu.org/licenses/gpl-3.0.en.html/)

A user-friendly interactive tool for Linux Debian and Alpine Linux user management, shell configuration (ZSH/Fish), and SSH key connectivity. Built with Bash and Dialog for a seamless command-line experience.

## ✨ Features
- User Management
- Shell Setup
- SSH Connection
- Installation option for system-wide availability

## 🚀 Quick Start

### One-Line Install
```bash
curl -fsSL https://raw.githubusercontent.com/peterweissdk/user_init/main/install.sh | bash
```
The installer will prompt you to choose between **Debian/Ubuntu** or **Alpine Linux** version.

### Manual Installation
1. Clone this repository:
   ```bash
   git clone https://github.com/peterweissdk/user_init.git
   ```

2. Make the script executable:
   ```bash
   chmod +x user_init.sh        # For Debian/Ubuntu
   chmod +x user_init-alpine.sh  # For Alpine Linux
   ```

3. Run the script:
   ```bash
   sudo ./user_init.sh           # For Debian/Ubuntu
   sudo ./user_init-alpine.sh    # For Alpine Linux
   ```

### Usage Options
- `-v, --version`: Display current version
- `-u, --update`: Update script to latest version from GitHub
- `-h, --help`: Show help message

## 📝 Directory Structure
```bash
user_init/
├── .git
├── install.sh
├── user_init.sh
├── user_init-alpine.sh
├── LICENSE
└── README.md 
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 🆘 Support

If you encounter any issues or need support, please file an issue on the GitHub repository.

## 📄 License

This project is licensed under the GNU GENERAL PUBLIC LICENSE v3.0 - see the [LICENSE](LICENSE) file for details.