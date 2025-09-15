#!/bin/bash

# Virtual Environment Setup Script for Docker Backup
# This script creates a Python virtual environment and installs dependencies

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/backup_env"

echo "Setting up Python virtual environment for Docker backup..."
echo "Directory: $SCRIPT_DIR"

# Check if Python 3 is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Error: python3 not found. Please install Python 3."
    echo "   sudo apt update && sudo apt install python3 python3-venv python3-pip"
    exit 1
fi

# Create virtual environment
echo "🔧 Creating virtual environment..."
if [ -d "$VENV_DIR" ]; then
    echo "⚠️  Virtual environment already exists at $VENV_DIR"
    read -p "Do you want to recreate it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$VENV_DIR"
    else
        echo "Using existing virtual environment."
    fi
fi

if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
    if [ $? -ne 0 ]; then
        echo "❌ Failed to create virtual environment"
        echo "   Try: sudo apt install python3-venv python3-full"
        exit 1
    fi
    echo "✅ Virtual environment created at $VENV_DIR"
fi

# Activate virtual environment
echo "🔧 Activating virtual environment..."
source "$VENV_DIR/bin/activate"

# Upgrade pip
echo "⬆️  Upgrading pip..."
pip install --upgrade pip

# Install requirements
echo "📦 Installing Python packages..."
if [ -f "$SCRIPT_DIR/requirements.txt" ]; then
    pip install -r "$SCRIPT_DIR/requirements.txt"
    if [ $? -eq 0 ]; then
        echo "✅ All packages installed successfully!"
    else
        echo "❌ Failed to install some packages"
        exit 1
    fi
else
    echo "⚠️  requirements.txt not found, installing packages manually..."
    pip install pyTelegramBotAPI python-dotenv
fi

# Test installation
echo "🧪 Testing installation..."
python -c "import telebot; import dotenv; print('✅ All packages imported successfully')" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✅ Setup completed successfully!"
else
    echo "⚠️  Package import test failed, but installation may still work"
fi

echo ""
echo "📋 Next steps:"
echo "1. Configure your .env file:"
echo "   cp .env.example .env"
echo "   # Edit .env with your settings"
echo ""
echo "2. To run the backup script:"
echo "   cd $SCRIPT_DIR"
echo "   source backup_env/bin/activate"
echo "   python main.py"
echo ""
echo "3. To setup automated backups with virtual environment:"
echo "   ./setup_cron_venv.sh"
echo ""
echo "4. To deactivate virtual environment later:"
echo "   deactivate"

# Create activation helper script
cat > "$SCRIPT_DIR/activate.sh" << 'EOL'
#!/bin/bash
# Helper script to activate virtual environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/backup_env/bin/activate"
echo "✅ Virtual environment activated"
echo "Run 'deactivate' to exit"
EOL

chmod +x "$SCRIPT_DIR/activate.sh"
echo "💡 Created activate.sh helper script for easy activation"