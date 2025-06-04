#!/bin/bash
# twitch_nfo_generator.sh - Simplified background wrapper for the Twitch NFO Generator

# Configuration
TWITCH_DIR="/Volumes/media/twitch"
PYTHON_SCRIPT="/Users/pavel.karpovich/Projects/environment/scripts/twitch_nfo_generator.py"

# Set text colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to display error and exit
error_exit() {
    echo -e "${RED}ERROR: $1${NC}"
    exit 1
}

# Check for Python 3
if ! command -v python3 &> /dev/null; then
    error_exit "Python 3 is required but not found."
fi

# Check if the Python script exists
if [ ! -f "$PYTHON_SCRIPT" ]; then
    error_exit "Python script not found: $PYTHON_SCRIPT"
fi

# Check if the Twitch directory is mounted and accessible
if [ ! -d "$TWITCH_DIR" ]; then
    error_exit "Twitch directory not mounted at $TWITCH_DIR."
fi

# Run the Python script
echo -e "${YELLOW}Running Twitch NFO Generator...${NC}"
python3 "$PYTHON_SCRIPT" "$TWITCH_DIR" --force

# Check if the script ran successfully
if [ $? -eq 0 ]; then
    echo -e "${GREEN}NFO generation completed successfully!${NC}"
else
    error_exit "NFO generation failed."
fi
