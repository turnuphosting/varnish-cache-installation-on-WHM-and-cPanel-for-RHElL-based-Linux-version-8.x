.PHONY: all download run clean uninstall

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

# Target to stop and uninstall Varnish and Hitch
uninstall:
	sudo systemctl stop varnish
	sudo systemctl stop hitch
	sudo dnf remove varnish -y
	sudo dnf remove hitch -y
	sudo systemctl daemon-reload
	sudo systemctl restart httpd
