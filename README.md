# [ScreenHint](https://screenhint.com)

A screenshotting tool for thinking clearly.

![A screenshot of a bunch of hints](https://github.com/salemhilal/screenhint-site/blob/main/src/static/img/just-hints.png?raw=true)

## How to publish

1. Bump the version and build numbers under ScreenHint's "General" settings.
2. In Xcode, build an archive (`Product > Archive`). The "Archives" window should open once the archive is built.
3. Select the built version in the "Archives" window and select "Validate App". 
	- Check "Upload Symbols" and "Manage Version and Build Number"
	- Select "Automatically manage signing" 
4. After validation is completed, select "Distribute App".
	- Distribute via "App Store Connect"
	- Upload the app directly to App Store Connect
	- As before, upload symbols and automatically manage signing. 
5. Go to App Store Connect and submit a new version for the app.
	- Go to https://appstoreconnect.apple.com/ and select "My Apps"
	- Select "ScreenHint"
	- By "macOS App", hit the "+" button and enter the new version number.
	- On the "Version Information" screen, enter release notes in the "What's New in This Version" field.
	- Under the "Build" section, select the "+" button and select the version you just uploaded. Walk through any questions about encryption.
	- At the top of the page, select "Save" and then "Add for Review".
	- Select "Submit for Review" to actually submit your app to the Apple review process.



ScreenHint © 2021 by [Salem Hilal](https://salem.io)


