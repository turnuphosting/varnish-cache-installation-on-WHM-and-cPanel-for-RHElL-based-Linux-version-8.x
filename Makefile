.PHONY: all download run setup-cron clean uninstall

# URL of the Varnish and Hitch installation script
INSTALL_SCRIPT_URL=https://raw.githubusercontent.com/turnuphosting/varnish-cache-installation-on-WHM-and-cPanel-for-RHElL-based-Linux-version-8.x/main/install_varnish_hitch.sh

# URL of the Hitch update script
UPDATE_SCRIPT_URL=https://raw.githubusercontent.com/turnuphosting/varnish-cache-installation-on-WHM-and-cPanel-for-RHElL-based-Linux-version-8.x/main/update_hitch_certs.sh

# Script file names
INSTALL_SCRIPT_NAME=install_varnish_hitch.sh
UPDATE_SCRIPT_NAME=update_hitch_certs.sh

# Default target
all: download run setup-cron

# Target to download the scripts
download:
	curl -O $(INSTALL_SCRIPT_URL)
	curl -O $(UPDATE_SCRIPT_URL)

# Target to make the scripts executable and run the install script with sudo
run: download
	chmod +x $(INSTALL_SCRIPT_NAME) $(UPDATE_SCRIPT_NAME)
	sudo ./$(INSTALL_SCRIPT_NAME)

# Target to setup the cron job
setup-cron:
	crontab -l > mycron || true
	echo "*/5 * * * * /root/varnish-cache-installation-on-WHM-and-cPanel-for-RHElL-based-Linux-version-8.x/$(UPDATE_SCRIPT_NAME)" >> mycron
	crontab mycron
	rm mycron

# Target to clean up downloaded scripts
clean:
	rm -f $(INSTALL_SCRIPT_NAME) $(UPDATE_SCRIPT_NAME)

# Target to stop and uninstall Varnish and Hitch
uninstall:
	sudo systemctl stop varnish
	sudo systemctl stop hitch
	sudo dnf remove varnish -y
	sudo dnf remove hitch -y
	sudo systemctl daemon-reload
	sudo systemctl restart httpd
	crontab -l | grep -v "/root/varnish-cache-installation-on-WHM-and-cPanel-for-RHElL-based-Linux-version-8.x/$(UPDATE_SCRIPT_NAME)" | crontab -
