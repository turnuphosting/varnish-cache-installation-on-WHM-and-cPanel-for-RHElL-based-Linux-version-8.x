# varnish-cache-installation-on-WHM-and-cPanel-for-RHElL-based-Linux-version-8.x
The installation script provides guidelines on how to install Varnish Cache as seen at https://varnish-cache.org/ on RHEL based Linux (eg. AlmaLinux 8) that has WHM/cPanel. Read more about Varnish Cache here https://varnish-cache.org/intro/index.html#intro.

# Please Note:
Before you begin, Go to WHM and search for Tweak Settings, it can be found at Server Configuration > Tweak Settings.
Search apache in the Find box, scroll down under System area and change the areas like below.
For Apache non-SSL IP/port, change from default 0.0.0.0:80 default to 0.0.0.0:8080 using the text box below.
For Apache SSL port, change from 0.0.0.0:443 default to 0.0.0.0:8443 using the text box below.
Save changes and search HTTP Server (Apache) in the search box, and click on Restart.
This would temporarily make user websites inaccessible until finished.

# Installing
`git clone` this repository, cd into the directory. Run `make clean`.
Once done, run `vi /etc/varnish/default.vcl` and compare and add missing ones from https://github.com/turnuphosting/varnish-cache-installation-on-WHM-and-cPanel-for-RHElL-based-Linux-version-8.x/blob/main/vcl%20config%20for%20wordpress to your vcl config.

# Varnish Cache Flush cPanel Plugin
You can go to https://github.com/turnuphosting/cPanel-plugin-to-flush-varnish-cache-for-user-websites and follow the steps there to install cPanel Plugin that'll allow your users to clear Varnish cache for their domains directly from cPanel.

# For WordPress users:
You can easily clear Varnish cache using this plugin https://wordpress.org/plugins/varnish-http-purge.
