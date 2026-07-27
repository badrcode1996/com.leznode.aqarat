# Storage bucket CORS — required for images on the web build

House/profile images are fetched from the bucket over plain HTTP. Under the
Flutter web CanvasKit renderer, the browser blocks those responses unless the
**bucket itself** carries a CORS policy — the `firebasestorage.googleapis.com`
download endpoint returns `Access-Control-Allow-Origin: *` only on error
responses, not on the actual object bytes, so a bucket with no CORS config makes
every image fail to paint even though the object exists and is public-read.

`firebase deploy` does NOT set bucket CORS. If images stop showing on the web —
especially after the default bucket is deleted and recreated — reapply it:

Open Cloud Shell from the Google Cloud console (it is authenticated as the
project owner) and run, from this repo's root or after uploading `cors.json`:

```bash
gsutil cors set cors.json gs://aqarat-49fc2.firebasestorage.app
```

Verify:

```bash
gsutil cors get gs://aqarat-49fc2.firebasestorage.app
```

The policy lives in `cors.json`. It allows GET/HEAD from any origin, which is
fine because the images it serves (`property_images`, `user_photos`,
`company_logos`) are all public-read branding.
