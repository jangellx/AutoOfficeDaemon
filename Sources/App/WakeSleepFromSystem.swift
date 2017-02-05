//
//  WakeSleepFromSystem.swift
//  AutoOfficeDaemon
//
//  Created by Joe Angell on 1/28/17.
//
// The wake/sleep handler listens for display wake/sleep events from the system.
//  Simple enough.  It is also our ApplDelegate.
//

import AppKit
import IOKit
import JSON
import HTTP

class WakeSleepHandler : NSObject, NSApplicationDelegate {
	// Once the application finishes launching, we register for display sleep and wake events
	func applicationDidFinishLaunching(_ aNotification: Notification) {
		// Listen for wake/sleep notifications
		NSWorkspace.shared().notificationCenter.addObserver(self, selector: #selector( sleepListener(_:) ), name: NSNotification.Name.NSWorkspaceScreensDidSleep, object: nil)
		NSWorkspace.shared().notificationCenter.addObserver(self, selector: #selector( sleepListener(_:) ), name: NSNotification.Name.NSWorkspaceScreensDidWake,  object: nil)
	}

	// This commun function is used to handle if the display is currently asleep or awake,
	//  storing the state in isAwake.
	@objc func sleepListener(_ aNotification:NSNotification) {
		if aNotification.name == NSNotification.Name.NSWorkspaceScreensDidSleep {
			print("Display slept; arming timer to send message to SmartThings")
			isAwake = false
			armTimer()				// Arm the timer

		} else if aNotification.name == NSNotification.Name.NSWorkspaceScreensDidWake {
			print("Display woke; stopping timer and sending message to SmartThings")
			isAwake = true

			timer?.invalidate()			// Stop the timer
			timer = nil;				// Clear it to empty

			putToSmartApp( isAwake )			// Tell SmartThinsg to wake up

		} else {
			print("Unknown sleep/wake event")

		}
	}
	
	// Tell SmartThings to wake or sleep
	func putToSmartApp( _ asWake: Bool ) {
		do {
			let json = try JSON(node: [
				"command": asWake ? "wake" : "sleep"
			])

			// Get values from the config
			guard let baseURL = aod.drop.config[ "app", "app_url" ]?.string  else {
				print("app_url not defined in Configs/app.json; cannot generate URL to call SmartApp")
				return;
			}

			guard let appID = aod.drop.config[ "app", "app_id" ]?.string  else {
				print("app_id not defined in Configs/app.json; cannot generate URL to call SmartApp")
				return;
			}

			guard let token   = aod.drop.config[ "app", "access_token"]?.string else {
				print("app_token not defined in Configs/app.json; cannot generate URL to call SmartApp")
				return;
			}

			// Compile the URL and JSON
			let url       = baseURL + appID + "/do" + (isAwake ? "/wake" : "/sleep")
			let jsonBytes = try json.makeBytes()

			// Call the URL
			print("Sending message to SmartApp at \(url)")
			try _ = aod.drop.client.put( url, headers: ["Authorization": "Bearer " + token], body: Body.data( jsonBytes ) )

		} catch {
			print( "Failed to issue command to SmartApp" )
		}
	}
	
	// Arm a timer, which we use to send a delayed sleep notification to SmartThings.
	func armTimer() {
		guard let delayInSeconds = aod.drop.config[ "app", "sleep_delay" ]?.int else {
			// No delay defined; fire the action now
			putToSmartApp( isAwake )
			return;
		}
		
		if( delayInSeconds == 0 ) {
			// No delay defined; fire the action now
			putToSmartApp( isAwake )
			return;
		}
		
		// Delay defined; arm the timer
		print( "Arming timer for \(delayInSeconds) seconds to notify SmartApp to sleep" )
		timer = Timer.scheduledTimer( timeInterval: Double(delayInSeconds),
		                              target: self, selector: #selector( timerFire ),
					      userInfo: nil, repeats: false)
	}

	// The timer has fired; send the sleep/wake message to SmartThings
	@objc func timerFire() {
		putToSmartApp( isAwake );
	}

	// Variables
	var isAwake          = true
	var timer : Timer? = nil
}
