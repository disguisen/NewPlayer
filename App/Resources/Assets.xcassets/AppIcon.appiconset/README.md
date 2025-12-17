# App Icon Placeholder

The repository omits binary icon PNGs to avoid Git hosting errors about unsupported binary artifacts. Add your generated icon set locally into this folder when building or submitting to the App Store, but keep the PNGs out of version control.

Suggested workflow:
1. Generate icons with your preferred tool (e.g., Xcode Asset Catalog Creator or `iconutil`).
2. Drop the PNGs here for local builds.
3. Before committing, ensure `App/Resources/Assets.xcassets/AppIcon.appiconset/*.png` remains untracked (covered by `.gitignore`).
