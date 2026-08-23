# Google Maps keys

The property pin on a listing (`LocationPicker`) draws a real Google map, which
needs an API key per platform. Without one the map area comes up grey — nothing
crashes, and every other screen works — so a checkout with no keys is still
usable for development.

Billing must be enabled on the Google Cloud project. Google's monthly free
allowance is far larger than this app will use, but the card has to be on file
or every request is refused.

## 1. Turn the APIs on

In the `aqarat-49fc2` project, enable:

| API | Used by |
| --- | --- |
| Maps SDK for Android | the Android build |
| Maps SDK for iOS | the iOS build |
| Maps JavaScript API | the web build |

## 2. Make three keys, not one

One key per platform, because each platform is restricted a different way and a
single shared key can only carry one kind of restriction.

**Every key must be restricted.** An unrestricted Maps key is a bill anyone can
run up: it is visible in the app bundle and in the page source, and there is no
way to hide it. Restriction — not secrecy — is what protects it.

| Key | Application restriction | API restriction |
| --- | --- | --- |
| Android | package `com.leznode.aqarat` + the signing SHA-1 | Maps SDK for Android |
| iOS | bundle id `com.leznode.aqarat` | Maps SDK for iOS |
| Web | HTTP referrer `aqarat.leznode.com/*` (add `localhost:*` while developing) | Maps JavaScript API |

The Android SHA-1 is the one for the upload keystore in `android/key.properties`:

```bash
keytool -list -v -alias upload -keystore <path-to-upload-keystore.jks>
```

Play App Signing re-signs the uploaded bundle, so the **app-signing** SHA-1 from
the Play Console has to be added to the same key as well, or the map is grey for
everyone who installed from the store while working fine from a local build.

## 3. Put each key where its platform reads it

**Android** — add to `android/key.properties`, which is already git-ignored
because the signing credentials live there:

```properties
mapsApiKey=AIza...
```

`build.gradle.kts` feeds it to `AndroidManifest.xml` as `MAPS_API_KEY`.

**iOS** — copy `ios/Flutter/Maps.xcconfig.example` to `Maps.xcconfig` beside it
and put the real key in:

```
MAPS_API_KEY = AIza...
```

Nothing else to wire: `Debug.xcconfig` and `Release.xcconfig` already
`#include?` it (optionally, so a checkout without the file still builds),
`Info.plist` reads `$(MAPS_API_KEY)`, and `AppDelegate.swift` hands it to
`GMSServices`. `Maps.xcconfig` is git-ignored.

**Web** — replace `YOUR_WEB_MAPS_API_KEY` in `web/index.html`. This one IS
committed, and that is fine: a referrer-restricted web key is public by design.
It is the restriction that has to be right.

## What is stored

`lat` / `lng` on a `properties` document, written as a pair or not at all.

They are deliberately **absent from the `market` projection**. The market hides
`owner_name` and `owner_mobile` so another company has to go through the agent;
an exact position would let them skip the agent and knock on the owner's door,
which is the same leak by another route. If the market ever needs a location,
show the district, not the address.

## Plan gating

The map is a `PlanFeatures.map` feature: off for Bronze, on from Silver up. It
is a metered Google service, so it is priced as one. A single company can be
moved either way through its `feature_overrides` without shifting the tier.
