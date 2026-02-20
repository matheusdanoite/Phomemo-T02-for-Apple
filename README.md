# Phomemo T02 for Apple
[Versão em português](README.pt-br.md)


Third time's the charm! On my third iteration of connecting my Apple devices to a Phomemo T02 printer, this project consists of an iOS app and a Web App (React) to enable printing images and text on this printer model via Bluetooth, using Firebase to allow third parties to send data to be printed locally via Bluetooth. I love this printer model!

## How it Works
You can deploy the web app (or not) to a web address, and anyone who accesses that page will be able to send files to be printed on your printer. When a file is sent, it is converted to Base64 and sent to Firebase. When the app in this repository receives "the blessing of iOS" to run in the background, it checks for updates. If there are any, Firebase transmits the data, which is decoded on the device and printed via Bluetooth. Once printed, the data is deleted from Firebase.

### Multipeer Connectivity
I also added a feature that allows sharing the printer with other people running the same app. A multipeer connection is created using Apple's `MultipeerConnectivity` framework to allow exactly that: a local network without a central server. When a device opens the app, it automatically starts in **Client Mode**. In this mode, it searches for other available devices in **Host Mode** or for printers to connect to; once it connects to a printer, it assumes the Host role. As a Host, its job is to route all received print jobs to the printer, including those from connected clients.

### App Intents & Shortcuts
There is also support for App Intents: you can print text or your clipboard via Siri, Shortcuts, or any other Apple gear. There are two intents: one for printing text and images, and another for the clipboard. The text & image one is my favorite: a space for an image, followed by a title and text. I made a "fax" for printing messages I receive via iMessage and use it as a memory keeper: I take a photo, write a caption, and print it with the title configured to pull the photo's creation date and time. Cool, right? People usually love it at meetups.

## Project Structure
- **/iOSApp**: Contains the Xcode project (.xcodeproj) and Swift source code. The app manages the Bluetooth connection with the printer and acts as a Print Host or Client.
- **/WebApp**: Contains the React frontend (Vite) used to process images (dithering algorithms like Floyd-Steinberg) before sending them for printing.

## How to Configure
### 1. Firebase (Required)
The project uses Firebase Firestore and Storage. To run it, you will need your own configuration files:

1. Create a project in the [Firebase Console](https://console.firebase.google.com/).
2. **iOS**:
   - Add an iOS app to your Firebase project.
   - Download the `GoogleService-Info.plist` file.
   - Place it at `iOSApp/GoogleService-Info.plist` (use the `.example` file as a reference).
3. **Web**:
   - Add a Web App to your Firebase project.
   - Copy the credentials and fill in the `WebApp/src/firebaseConfig.js` file (use the `firebaseConfig.example.js` file as a reference).

### 2. Running the Web App
```bash
cd WebApp
npm install
npm run dev
```

### 3. Running the iOS App
Open `iOSApp/t02web.xcodeproj` in Xcode, ensure you configure your *Development Team* in the *Signing & Capabilities* tab, and run it on a physical device (Bluetooth is required).

## Final Considerations
Print jobs are all processed on the source device, and it also works great on macOS — you can build it for Mac as well. It was vibecoded to the max, and I apologize for that — but at least it worked here.

Developed by **matheusdanoite chaebol**.
