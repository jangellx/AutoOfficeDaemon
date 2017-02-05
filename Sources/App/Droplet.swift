//
//  Droplet.swift
//  AutoOfficeDaemon
//
//  Created by Joe Angell on 1/28/17.
//
//  Handles the Vapor droplet, including responding to URLs
//
//

import IOKit
import Vapor

class AODDroplet {
	init() {
		drop = Droplet();

		// Add the post controller.  We don't actually use this for anything yet.
		drop.resource("posts", PostController())

		// Set up our handlers
		// - Default welcome page (from Vapor)
		drop.get { req in
			return try self.drop.view.make("welcome", [
				"message": self.drop.localization[req.lang, "welcome", "title"]
			])
		}

		// /status: Return if the computer is awake or not as JSON
		drop.get( "status" ) { req in
			return try JSON( node:[
				"isAwake": wakeSleepHandler.isAwake ? 1 : 0
			])
		}

		// /wake: Wake the display and return that it is awake as JSON
		drop.get( "wake" ) { req in
			self.sleepDisplay( false )

			return try JSON( node:[
				"isAwake": wakeSleepHandler.isAwake ? 1 : 0
			])
		}

		// /sleep: Sleep the display and return that it is asleep as JSON
		drop.get( "sleep" ) { req in
			self.sleepDisplay( true )

			return try JSON( node:[
				"isAwake": wakeSleepHandler.isAwake ? 1 : 0
			])
		}

		// /do:  PUT request to put wake/sleep the machine
		drop.put( "do" ) { req in
			guard let command = req.json?["command"]?.string else {
				throw Abort.badRequest
			}

			if( command == "wake" ) {
				self.sleepDisplay( false )
			} else if ( command == "sleep" ) {
				self.sleepDisplay( true )
			} else {
				throw Abort.custom(status: .badRequest, message: "Invalid command")
			}

			return try JSON( node:[
				"isAwake": wakeSleepHandler.isAwake ? 1 : 0
			])
		}
	}
	
	// Sleep or wake the diaplsy
	func sleepDisplay( _ goToSleep:Bool) {
		// Only do something if we're not already in that state
		if( wakeSleepHandler.isAwake == !goToSleep ) {
			return;
		}

		let reg   = IORegistryEntryFromPath(kIOMasterPortDefault, "IOService:/IOResources/IODisplayWrangler")
		let entry = "IORequestIdle" as CFString

		IORegistryEntrySetCFProperty(reg, entry, goToSleep ? kCFBooleanTrue : kCFBooleanFalse );
		IOObjectRelease(reg);
	}

	// Spawn the server in a background thread
	func spawnInBackground() {
		DispatchQueue.global(qos: .background).async {
			self.drop.run()
		}
	}

	let drop: Droplet
}
