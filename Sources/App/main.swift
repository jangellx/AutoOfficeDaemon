// Main file.  We just set up everything, spawn Vapor in a background thread,
//  and run the main input loop.

import AppKit

// Initialize our classes
let wakeSleepHandler = WakeSleepHandler()
let aod              = AODDroplet()

// Initialize the application and set the app delegate
let app      = NSApplication.shared()
app.delegate = wakeSleepHandler

// Run Vapor in a backgorund thread.  We need to do this so that we can listen for system
//  sleep/wak events in the main thread and not block the AppDelegate.
aod.spawnInBackground()

// Run the main loop so we can get sleep/wake notifications
app.run()
