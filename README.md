# 📝 Credits

### Author
**grombor**

### Version
**1.0.1**

### Special Thanks

Thanks to everyone who participated in testing, debugging, and providing feedback during development.

Your reports helped improve inventory interaction handling, Blizzard bag compatibility, appearance collection support, secure item usage, combat behavior, and overall addon stability.

### Early Testers

Special thanks to the early testers who helped identify bugs, validate fixes, and improve the overall user experience:

- **Slimeee**
- **KlintenS**
- **plutonium98**
- **Maro**
- **Edgedick**

Your time, bug reports, testing sessions, and feedback were invaluable throughout development.

---

# 📋 Changelog

## Version 1.0.1

### Inventory Window
- Added support for closing the BagTags inventory window with the **ESC** key.
- Added automatic closing of the BagTags inventory window when entering combat.
- Improved inventory window behavior to better match Blizzard UI standards.

### Inventory Interaction
- Fixed left-click item pickup within the BagTags grouped inventory window.
- Fixed drag & drop functionality for custom inventory slots.
- Fixed secure interaction conflicts affecting item movement.
- Restored proper compatibility with Blizzard inventory actions.
- Improved item interaction reliability for custom inventory buttons.
- Fixed issues where custom inventory slots could behave differently from native bag slots.

### Secure Action Handling
- Reworked inventory slot click processing.
- Separated manual item pickup handling from secure item actions.
- Fixed conflicts between custom click handlers and `SecureActionButtonTemplate`.
- Resolved secure-function taint issues related to inventory interaction.
- Improved compatibility with protected Blizzard item APIs.

### Compatibility
- Improved compatibility with **Conquest of Azeroth**.
- Improved compatibility with appearance collection systems.
- Improved handling of secure right-click item actions.
- Improved synchronization of custom inventory slot data.

### Stability
- Fixed multiple edge cases related to item pickup and cursor handling.
- Fixed inconsistent behavior between drag-and-drop and click interactions.
- Improved overall addon reliability and inventory responsiveness.
