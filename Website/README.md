# Ventus website

Static Firebase Hosting site for the public Ventus landing page and App Clip domain association.

## First deployment

1. Authenticate the Firebase CLI from this directory:

   ```sh
   firebase login
   ```

2. Create a Firebase project (the project ID must be globally unique):

   ```sh
   firebase projects:create ventus-weather --display-name Ventus
   ```

3. Deploy the site:

   ```sh
   firebase deploy --only hosting --project ventus-weather
   ```

Firebase publishes this project at `https://ventus-52c5b.web.app`.

## Enable the App Clip card

After Ventus has an App Store ID, replace `YOUR_APP_STORE_ID` in `public/index.html` and uncomment the `apple-itunes-app` meta tag. Then add the deployed host to the Associated Domains entitlement in both the full iOS app and App Clip:

```
appclips:ventus-weather.web.app
```

The `public/.well-known/apple-app-site-association` file identifies the current Ventus App Clip application identifier and permits both `/forecast/*` and `/account/autologin/*` universal links.

## App Clip auto-login test link

Use this URL shape for an invocation test, replacing the placeholders with the real values:

```
https://ventus-52c5b.web.app/account/autologin/?binding_key=<token>&flow_type=<flow>
```

Register the URL prefix `https://ventus-52c5b.web.app/account/autologin/` as an App Clip experience in App Store Connect.
