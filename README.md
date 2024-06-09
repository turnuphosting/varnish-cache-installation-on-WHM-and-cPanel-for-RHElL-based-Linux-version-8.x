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
`git clone` this repository, `cd varnish-cache-installation-on-WHM-and-cPanel-for-RHElL-based-Linux-version-8.x` into the directory. Run `make`.
To uninstall Varnish and Hitch, Run `make uninstall` and change the ports as seen in the Note text above back to default.

# Varnish Cache Flush cPanel Plugin
You can go to https://github.com/turnuphosting/cPanel-plugin-to-flush-varnish-cache-for-user-websites and follow the steps there to install cPanel Plugin that'll allow your users to clear the Varnish cache for their domains directly from cPanel.

# For WordPress users:
You can easily clear the Varnish cache using this plugin https://wordpress.org/plugins/varnish-http-purge.
Edit your wp-config.php file in your root directory and add the code below. <br />
`if (!empty($_SERVER['HTTP_X_FORWARDED_PROTO'])) {
    $_SERVER['HTTPS'] = 'on';
}`

# Credits:
This was made possible with inputs from:
@guillaume and @neutrinou from Varnish Cache discord forum
and Andy Baugh from cPanel forums.
Thank you all.
