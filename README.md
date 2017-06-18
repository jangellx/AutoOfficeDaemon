# AutoOfficeDaemon
AutoOfficeDaemon is a simple web server built from the [Vapor](https://github.com/vapor/vapor) Swift web framework to assist with SmartThings-based home automaticion.  It's purpose is listen for incoming connections to wake or sleep the display of the macOS computer it is running on.  It also detects when the display wakes or sleeps and calls the SmartApp's URL so that other SmartThings-controlled devices can be turned on or off as well.

The end result is that by turning on any lights in my office or by waking my computer's display, all the lights turn on and my computer wakes up.  Similarly, turning off any of the lights or sleeping the computer's display turns off all the lights and sleeps the comptuer.

## Vapor Web Server
I used Vapor because it is very easy to set up and get running, and I didn't want to spend a huge amount of time on this.  The server's droplet runs in a background thread and listens for incoming connections on a port defined in servers.json.  The following URL paths are supported:
* /status (GET):  Simply returns some JSON indicating if the machine is awake or not.
* /wake and /sleep (GET): Puts the display to sleep or wakes it up.  You can trigger these from a web browser on your phone, for example, but auto-complete and pre-fetching mean that before you finish entering the URL it has probably already woken or slept the display.
* /do (Put):  This looks at the JSON formatted data a "command" property, waking the display if the value is "wake" and sleeping it on "sleep".

The Vapor HTTP client class is also used to make PUT calls to the SmartApp to let it know that the computer has woken or slept, thus allowing it to turn on or off other devices in response. 

## Sleep/Wake Handling
Code-wise, we listen for NSWorkspace notifications for NSWorkspaceScreensDidSleep and NSWorkspaceScreensDidWake, sending those to the SmartApp URL when they come in.

To respond to sleep/wake events from SmartThings, we use IORegistryEntrySetCFProperty() for "IOService:/IOResources/IODisplayWrangler", setting it to true (to go to sleep) or false (to wake it).

It's important to note that this only wakes/sleeps the display, not the entire computer.  If you want to do something like that, using "wake on LAN" is a better solution.  I only ever sleep my machines displays (thus allowing for various backups and other tasks to run), so detecting and triggering display sleep/wake is all I am interested in.

In order to listen for sleep/wake events, we need to set up an ApplicationDelegate and spawn an NSApplication.  This conflicts with the Vapor droplet, since that wants to run as a blocking function.  The solution was simply to run Vapor in a background thread.  Nice and easy.

## Installation
Installation is done per the instructions on the Vapor page to create a new project.  The AutoOfficeDaemon repository only includes the files unique to this project -- the sources and configs -- so you need to get the rest of the Vapor toolbox to get everything up and running.  It's pretty straight-forward, though; after creating an app, you simply replace the relevant files with those from this repository, build and go.

## Configuration
The SmartApp URL, application ID and OAuth2 access token are stored in Configs/app.config .  I borrowed how [homebridge-smartthings[(https://www.npmjs.com/package/homebridge-smartthings) does this, and have the SmartApp generate the config file.  You just copy the contents from the SmartApp on your phone, get it to your computer somehow (ie: paste it into the iOS Notes app), and paste it Configs/app.json .

Besides the SmartApp URL, application ID and OAuth2 access token, this includes a sleep delay.  The idea here is that I have multiple computers on my desk, and if one goes idle and sleeps while I'm using another one I usually immediately wake it back up.  However, I don't want all the lights and monitors to go off just because one machine unexpectedly went to sleep.  To resolve this, a sleep delay can be used to wait a certain number of seconds after display sleep signaling the SmartApp.

## Auto-Launching the Daemon
Vapor makes it easy to run the server -- just cd to the proejct dir and type "vapor run server".  The easiest way to automatically launch it is to use launchd, by creating a file in ~/Library/LaunchAgents/com.AutoOfficeDaemon.app.plist with these contents:

```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
	<dict>
		<key>Label</key>
		<string>com.AutoOfficeDaemon.app</string>

		<key>WorkingDirectory</key>
		<string>/Users/yourUsername/pathToDaemon/AutoOfficeDaemon</string>

		<key>Program</key>
		<string>/usr/local/bin/vapor</string>

		<key>ProgramArguments</key>
		<array>
			<string>/usr/local/bin/vapor</string>
			<string>run</string>
			<string>serve</string>
		</array>

		<key>RunAtLoad</key>
		<true/>

		<key>KeepAlive</key>
		<true/>
</dict>
</plist>
```

Replacing "yourUsername/pathToDaemon" with the actual location of your installation.  

When I tried to get this working on a new machine, "vapor run" gave me a runtime error for some reason, but he app still worked in Xcode, so I changed it to this:

```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>com.AutoOfficeDaemon.app</string>

	<key>WorkingDirectory</key>
	<string>/Users/yourUserName/pathToDaemon/AutoOfficeDaemon</string>

	<key>Program</key>
	<string>/Users/yourUserName/Library/Developer/Xcode/DerivedData/AutoOfficeDaemon-gmepnxgdollkryaqjgmhfqujuqpy/Build/Products/Debug/App</string>

	<key>RunAtLoad</key>
	<true/>

	<key>KeepAlive</key>
	<true/>
</dict>
</plist>
```

`AutoOfficeDaemon-gmepnxgdollkryaqjgmhfqujuqpy` is generated by Xcode, and you'll likely have to chagne it to match.  Vapor likes to call the app "App", which is annoyingly non-descript, but it gets the job done.

This will launch it on log-in and keep it alive, relaunching it if it crashes or otherwise quits.  To begin running the daemon manually, use:

    launchctl load ~/Library/LaunchAgents/com.AutoOfficeDaemon.app.plist

To unload it, run:

    launchctl unload ~/Library/LaunchAgents/com.AutoOfficeDaemon.app.plist

If launchctl says there's a problem with your plist, you can validate it with "plutil -lint ~/Library/LaunchAgents/com.AutoOfficeDaemon.app.plist".

For more information about launchd, see [launchd.info](http://www.launchd.info).  There are lots of good debugging tips there, too.

Note that you have to build the app from the command line (ie: "vapor build"), not from an Xcode project for this to work, or else "vapor run" won't be able to find the built app.

The app name is simply "App", so that's what you'll see in Activity Monitor and pgrep.  I'm honestly not entirely sure how to change the name of a Vapor-based app; the world of web apps where the entire source is deployed with the server and expects to be the only server running is a bit alien to conventional application developemnt, but it's not a big deal to me, so I haven't spent too much time on it.

## About the Code
This is really my first Swift app (I'm primarily a C programmer), so it's a bit clunky and not terribly object-oriented.  I don't use the controller, and the wake/sleep handler and Vapor server communicate through global variables rather than passing objects back and for.  This project is so simple that none of these are deal-brakers.

## Vapor Documentation
See the Vapor web framework's [documentation](http://docs.vapor.codes) for more details about Vapor.

