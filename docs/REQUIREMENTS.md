# Requirements

The Shave project, a Bash-to-C transpiler, requires the following tools and environment to function properly:

- **Bash**: The Shave transpiler is written in Bash and requires a Unix-like shell environment to run. It checks for Bash installation during execution.
- **GCC (GNU Compiler Collection)**: Necessary for compiling the generated C code into executables from Bash scripts. Shave validates the presence of GCC before proceeding with compilation.
- **Unix-like Operating System**: Such as Linux or macOS, to ensure compatibility with Bash scripting and system commands.
- **UPX (Ultimate Packer for eXecutables)**: Used for compressing the compiled executables to reduce their size. Shave requires UPX to be installed for the full compilation process.
- **NodeJS**: Required to run tree-sitter, which is used for parsing Bash scripts. NodeJS provides the runtime environment for npm packages like tree-sitter.
- **tree-sitter**: A parsing tool used for generating a Concrete Syntax Tree (CST) of Bash scripts. Shave requires tree-sitter for optimal parsing. It can be installed via npm.

Ensure all components are installed and properly configured on your system before using Shave. Each tool is necessary for the complete functionality of the transpiler.

## Installing Dependencies

Below are instructions for installing the required dependencies on different operating systems. Use the appropriate commands for your system to ensure all tools are available for Shave.

### Fedora

- **GCC and related tools**:  

  ```bash
  sudo dnf install gcc make
  ```

- **UPX**:  

  ```bash
  sudo dnf install upx
  ```

- **NodeJS and npm**:  

  ```bash
  sudo dnf install nodejs
  ```

- **tree-sitter**:  
  After installing NodeJS, install tree-sitter globally via npm:  

  ```bash
  sudo npm install -g tree-sitter-cli
  ```

### Ubuntu

- **GCC and related tools**:  

  ```bash
  sudo apt update
  sudo apt install build-essential
  ```

- **UPX**:  

  ```bash
  sudo apt install upx-ucl
  ```

- **NodeJS and npm**:  

  ```bash
  sudo apt install nodejs npm
  ```

- **tree-sitter**:  
  After installing NodeJS, install tree-sitter globally via npm:  

  ```bash
  sudo npm install -g tree-sitter-cli
  ```

### macOS

- **GCC and related tools**:  
  Install Xcode Command Line Tools, which includes GCC and Make:  

  ```bash
  xcode-select --install
  ```

- **UPX**:  
  Use Homebrew to install UPX:  

  ```bash
  brew install upx
  ```

- **NodeJS and npm**:  
  Use Homebrew to install NodeJS:  

  ```bash
  brew install node
  ```

- **tree-sitter**:  
  After installing NodeJS, install tree-sitter globally via npm:  

  ```bash
  npm install -g tree-sitter-cli
  ```

## Building a C Version of Shave

Shave can be used to transpile itself into a C executable, creating a standalone version of the transpiler that can be run without Bash. This process demonstrates the self-hosting capability of Shave. Follow these steps to build a C version of Shave:

1. **Clone the Shave repository**: Download the Shave project to your local machine using Git. This will create a local folder named 'Shave' containing the project files.

   ```bash
   git clone https://github.com/500Foods/Shave.git
   ```

2. **Navigate to the Shave project directory**: Ensure you are in the root directory of the Shave project where `shave/shave.sh` is located.

   ```bash
   cd Shave
   ```

3. **Run Shave on its own script**: Use the Shave transpiler to convert `shave.sh` into a C executable. You can specify an output name for the executable; here, we use `shave-c`.

   ```bash
   ./shave/shave.sh -o shave-c shave/shave.sh
   ```

4. **Verify the executable**: After successful compilation, you will find the C executable `shave-c` in the current directory. You can run it to test its functionality.

   ```bash
   ./shave-c --help
   ```

5. **Optional - Keep the generated C source**: If you want to inspect the generated C code for `shave.sh`, use the `-k` flag to keep the intermediate C file.

   ```bash
   ./shave/shave.sh -o shave-c -k shave/shave.sh
   ```

6. **Install the executable globally**: To make the C version of Shave accessible from anywhere on your system, you can install it in `/usr/local/bin`. Use the following command to move the executable to this directory (requires sudo privileges).

   ```bash
   sudo mv shave-c /usr/local/bin/shave-c
   ```

   After installation, you can run `shave-c` from any directory to transpile Bash scripts to C executables.

This process will create a C version of Shave that retains the core functionality of the original Bash script, allowing for potential performance improvements and portability to environments where Bash might not be available.
