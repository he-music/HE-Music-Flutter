# Use liquid glass as a control surface

**Status: superseded by [ADR 0010](0010-use-sdk-interface-styles.md).**

This decision originally adopted `liquid_glass_widgets` for navigation and floating controls, with skins retaining responsibility for content and backgrounds. The implementation included adaptive rendering quality, shader warm-up and local focus/dialog patches.

The observed performance and interaction experience did not meet the product's needs. The dependency, vendored implementation and quality settings have been removed. The application now offers the Flutter SDK's Material and Cupertino design languages, independently of skins and brightness. See ADR 0010 for the current architecture and validation requirements.
