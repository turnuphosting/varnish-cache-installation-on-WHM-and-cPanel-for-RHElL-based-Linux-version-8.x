# varnish-cache-installation-on-WHM-and-cPanel-for-RHElL-based-Linux-version-8.x
The installation script provides guidelines on how to install Varnish Cache as seen at https://varnish-cache.org/ on RHEL based Linux (eg. AlmaLinux 8) that has WHM/cPanel. Read more about Varnish Cache here https://varnish-cache.org/intro/index.html#intro.

# Installing
`git clone` this repository, cd into the directory. Run `make clean`.
Once done, run `vi /etc/varnish/default.vcl` and compare and add missing ones from https://github.com/turnuphosting/varnish-cache-installation-on-WHM-and-cPanel-for-RHElL-based-Linux-version-8.x/blob/main/vcl%20config%20for%20wordpress to your vcl config.
