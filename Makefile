.PHONY: all download run clean

# URL of the script
SCRIPT_URL=https://raw.githubusercontent.com/turnuphosting/varnish-cache-installation-on-WHM-and-cPanel-for-RHElL-based-Linux-version-8.x/main/install_varnish_hitch.sh

# Script file name
SCRIPT_NAME=install_varnish_hitch.sh

# Default target
all: download run

# Target to download the script
download:
	curl -O $(SCRIPT_URL)

# Target to make the script executable and run it with sudo
run: download
	chmod +x $(SCRIPT_NAME)
	sudo ./$(SCRIPT_NAME)

# Target to clean up downloaded script
clean:
	rm -f $(SCRIPT_NAME)
