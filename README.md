# BagTags (v1.0.1)

**BagTags** is an advanced inventory enhancement addon for World of Warcraft 3.3.5a, designed and optimized for custom realms such as **Conquest of Azeroth** and **Project Ascension**.

BagTags helps players make smarter inventory decisions by providing real-time visual item tags, market value analysis, soulbound tracking, appearance collection support, and a modern categorized inventory interface.

Unlike traditional bag addons, BagTags can operate in two different modes: a fully customizable grouped inventory window or the native Blizzard bag interface enhanced with BagTags overlays.

<img width="368" height="395" alt="Zrzut ekranu 2026-07-25 075826" src="https://github.com/user-attachments/assets/55dc929a-e9f4-419a-bc43-2df66492c5b7" />
<img width="416" height="515" alt="Zrzut ekranu 2026-07-25 075807" src="https://github.com/user-attachments/assets/ff5d5deb-92f1-4e94-b433-578b8b1d1ad6" />
<img width="566" height="437" alt="Zrzut ekranu 2026-07-25 075739" src="https://github.com/user-attachments/assets/f10daa27-6d2a-4e04-9d4e-67d70f1abeb4" />
<img width="565" height="437" alt="Zrzut ekranu 2026-07-25 075729" src="https://github.com/user-attachments/assets/9b8dd56a-7736-483b-b3ac-d1f7520fbf9a" />




---

# 🚀 Key Features

## Smart Inventory Tagging

BagTags overlays actionable indicators directly on your items:

### **[A] Auction House**
Highlights items whose estimated Auction House value is significantly higher than vendor value.

### **[D] Disenchant**
Suggests disenchanting rare and uncommon equipment when projected material value exceeds vendor price.

### **[V] Vendor**
Marks junk and low-value equipment that is more profitable to sell directly to merchants.

### **[S] Soulbound**
Displays a visual marker for soulbound items to simplify inventory management and gear tracking.

---

## Dual Inventory Modes

Choose the inventory experience that best fits your playstyle:

### BagTags Grouped Inventory

- Automatic category grouping
- Collapsible item sections
- Category vendor value summaries
- Custom inventory window
- ESC key support
- Automatic window closing when entering combat

### Blizzard Bags + BagTags Overlays

- Native Blizzard inventory behavior
- Full BagTags overlay support
- Appearance collection compatibility
- Seamless integration with existing UI workflows

---

## Appearance Collection Support

Designed with Conquest of Azeroth compatibility in mind:

- Ctrl+Alt+Click appearance collection support
- Appearance tracking integration
- Wardrobe compatibility improvements
- Native inventory appearance handling

---

## Market Value Analysis

<img width="368" height="395" alt="Market Value Analysis" src="https://github.com/user-attachments/assets/1fb9f7fd-d329-4502-9fc0-10c09369d4a7" />

BagTags evaluates multiple item outcomes:

- Vendor value
- Auction House value
- Disenchant value

The addon automatically highlights the most profitable action for each item.

---

## Customizable Inventory Window

Customize the grouped inventory interface with:

- Adjustable window scale
- Adjustable opacity
- Draggable inventory frame
- Minimap launcher
- Category collapsing and expansion
- Saved window position

---

## Smart Category Management

<img width="416" height="515" alt="Category Management" src="https://github.com/user-attachments/assets/7569975f-8b86-427b-b115-01812c28e8fc" />

Items are automatically grouped into categories such as:

- New Items
- Consumables
- Tradeskill Materials
- Quest Items
- Equipment
- Miscellaneous

Additional categories can be created automatically based on item classification.

---

## Blizzard Bag Enhancements

BagTags fully supports:

- Native Blizzard container windows
- Real slot-level overlay tracking
- Accurate item detection
- Automatic refresh handling
- Secure item interactions
- Appearance collection support
- Improved inventory interaction support

---

# ⚙️ In-Game Configuration

<img width="565" height="437" alt="Configuration 1" src="https://github.com/user-attachments/assets/f9bbc283-3c61-456e-83fb-a52511c44c02" />

<img width="566" height="437" alt="Configuration 2" src="https://github.com/user-attachments/assets/3a70e909-d0a5-4247-b9b0-e4cb68add6d0" />

All major features can be configured through the in-game options panel.

Available settings include:

- Enable/Disable BagTags Inventory Window
- Window Opacity
- Window Scale
- Auction Tags
- Disenchant Tags
- Vendor Tags
- Soulbound Tags

The addon also provides a minimap button with context-sensitive behavior based on your selected inventory mode.

images/02.png

---

# 🛠️ Chat Commands

| Command | Action |
|----------|----------|
| `/bg` | Open BagTags options panel |
| `/bagtags` | Open BagTags options panel |
| `/bts` | Toggle BagTags inventory window |

Additional diagnostic and developer commands may be available in future releases.

---

# 🎮 Supported Interactions

BagTags supports:

- Left-click item pickup
- Right-click item usage
- Shift-click item linking
- Ctrl-click actions
- Ctrl+Alt appearance collection
- Item dragging and dropping
- Native Blizzard inventory functionality
- Secure item interactions
- Combat-safe inventory handling

---

# 📦 Installation

1. Download the latest release of **BagTags**.
2. Extract the addon folder into:

```text
World of Warcraft\Interface\AddOns\
```

3. Ensure the folder name is:

```text
BagTags
```

4. Launch the game.
5. Verify that **BagTags** is enabled on the AddOns screen.
6. Log in and enjoy.

---

# ⚙️ Requirements & Compatibility

### Supported Client

- World of Warcraft 3.3.5a

### Designed For

- Conquest of Azeroth
- Project Ascension
- Other custom 3.3.5a servers

### Recommended Addons

- Auctionator (for Auction House integration and pricing analysis)

### Compatible With

- Native Blizzard Bags
- Blizzard Inventory API
- Appearance Collection systems
- Most standard UI modifications

---

# 📋 Changelog

## Changelog v1.1

Inventory Window
* Optimized the overlay refresh process in the inventory module by removing redundant operations.

Item Interaction & Sell Actions
* Added a comprehensive item valuation system (`GetBestValueTag`) taking into account binding status, new items, auction house, disenchanting, and vendor value.
* Introduced queuing and automated selling support for items marked for the vendor (`SellVendorItems` and `StartVendorSellQueue`).
* Added a module for calculating the cumulative vendor value of items, accounting for stack counts.
* Added a quick vendor sell button with dynamic currency formatting and trade event handling.

Compatibility & Stability
* Added safe helper functions (`SafeGetContainerItemInfo`, `SafeGetContainerItemLink`) utilizing error-protected procedures.
* Implemented an inventory state monitoring and handling system as well as item data caching to improve performance.

## Version 1.0.1

### Inventory Window

- Added support for closing the BagTags inventory window with the **ESC** key.
- Added automatic closing of the inventory window when entering combat.
- Improved inventory window behavior to better match Blizzard UI standards.

### Inventory Interaction

- Fixed left-click item pickup within the BagTags grouped inventory window.
- Fixed right-click item interaction handling.
- Fixed drag & drop functionality for custom inventory slots.
- Fixed secure interaction conflicts affecting item movement.
- Restored proper compatibility with Blizzard inventory actions.
- Improved item interaction reliability for custom inventory buttons.

### Secure Action Handling

- Reworked inventory slot click processing.
- Separated manual item pickup handling from secure item actions.
- Fixed conflicts between custom click handlers and `SecureActionButtonTemplate`.
- Resolved secure-function taint issues related to inventory interaction.
- Improved compatibility with protected Blizzard item APIs.

### Compatibility

- Improved compatibility with **Conquest of Azeroth**.
- Improved appearance collection behavior.
- Improved secure right-click item actions.
- Improved synchronization of custom inventory slot data.

### Stability

- Fixed multiple edge cases related to item pickup and cursor handling.
- Fixed inconsistent behavior between drag-and-drop and click interactions.
- Improved overall addon reliability and inventory responsiveness.

---

# 📄 License

This project is licensed under the MIT License.

See the LICENSE file for details.

---

# 📝 Credits

### Author

**grombor**

### Version

**1.0.1**

### Special Thanks

Thanks to everyone who participated in testing, debugging, and providing feedback during development.

Your reports helped improve Blizzard bag compatibility, appearance collection support, inventory interaction handling, secure item actions, combat behavior, and overall addon stability.

### Early Testers

Special thanks to the early testers who helped identify bugs, validate fixes, and improve the overall user experience:

- **Slimeee**
- **KlintenS**
- **plutonium98**
- **Maro**
- **Edgedick**

Your time, testing sessions, bug reports, and feedback were invaluable throughout development.
