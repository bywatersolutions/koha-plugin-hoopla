# Introduction

This plugin allows users to search your Hoopla collection and checkout titles directly from the Koha catalog. Users will need a valid cardnumber and your library must have user authentication
setup to work with Koha/Hoopla.

# Downloading

From the [release page](https://github.com/bywatersolutions/koha-plugin-hoopla/releases) you can download the relevant *.kpz file

# Installing

To install simply download the latest release, browse to Administration->Plugins in your koha system, and click 'Upload plugin' and choose the file

The plugin system needs to be turned on by a system administrator.

To set up the Koha plugin system you must first make some changes to your install.

* Change `<enable_plugins>0<enable_plugins>` to `<enable_plugins>1</enable_plugins>` in your koha-conf.xml file
* Confirm that the path to `<pluginsdir>` exists, is correct, and is writable by the web server
* Restart your webserver

Once set up is complete you will need to alter your UseKohaPlugins system preference.

# Setup

The plugin has a configuration page where you will need to enter your library ID as supplied by Hoopla.

You will also need a username/password added your koha-conf.xml file on your Koha sever to access the hoopla api, if you are using a support vendor they should eb able to obtain these for you.
They should be added in the config section like:
```
<hoopla_api_username>YOUR_USERNAME</hoopla_api_username>
<hoopla_api_password>YOUR_PASSWORD</hoopla_api_password>
```

This plugin utilizes the Koha REST api to interact with the Hoopla api.

