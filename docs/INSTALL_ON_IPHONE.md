# Put the app on your iPhone (short steps)

### If Xcode says “unpaired” or the phone never shows as Run destination

1. **Unlock** the iPhone and keep it unlocked while pairing.
2. Unplug/replug the cable (try a **data** USB‑C/Lightning cable, not charge-only).
3. On the iPhone, tap **Trust** when “Trust This Computer?” appears (enter passcode).
4. On the Mac, open **Xcode** → menu **Window → Devices and Simulators** (or **⌘⇧2**).
5. Select **Jaideep’s iPhone** (or your device) in the left list. If you see **Pair** or **Prepare**, click it and **confirm on the phone** (any PIN/prompt).
6. Wait until the device shows **Ready** / green indicator, not “unpaired”.
7. Close the window, open this project again, pick your iPhone in the **scheme** dropdown (top bar), then **⌘R**.

---

1. **Plug in** the iPhone → unlock → tap **Trust This Computer** if asked.
2. **iPhone:** Settings → **Privacy & Security** → **Developer Mode** → **On** (restart if needed).
3. **Mac:** Open **`VoiceCloneAAC.xcodeproj`** in Xcode.
4. **Signing:** Click the blue project icon → target **VoiceCloneAAC** → **Signing & Capabilities** → turn on **Automatically manage signing** → pick your **Team** (add Apple ID under Xcode **Settings → Accounts** if needed).
5. **Run target:** Top bar → choose **your iPhone** (not a simulator).  
   If it says *pairing in progress* → finish trust on the phone and wait until Xcode shows it ready.
6. Press **▶ Run** (or **⌘R**).
7. **First launch on phone:** Settings → **General** → **VPN & Device Management** → your developer app → **Trust**.

**If Run is grayed out:** fix signing errors (try a unique **Bundle Identifier** under target **General**, e.g. `com.yourname.voicecloneaac`).

**API URL:** In `VoiceCloneAAC/Utilities/Constants.swift`, set `apiBaseURLString` to your live backend (no trailing slash), or the app cannot log in or speak.
