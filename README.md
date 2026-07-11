# BagTags (v0.7.3)

**BagTags** is a lightweight, high-performance inventory management addon for World of Warcraft 3.3.5a (optimized for custom realms like *Project Ascension*). It eliminates the guesswork from inventory management by overlaying dynamic smart tags on your items based on real-time market data, ensuring you always make the most profitable decision when clearing your bags.

Additionally, BagTags features a custom, safe asynchronous sorting engine that completely fixes the native broken bag sorting functionality in Bagnon.

![BagTags Inventory Overview](images/01.png)

---

## 🚀 Key Features

*   **Dynamic Smart Tagging:** Overlays actionable indicators directly onto item icons in your bags:
    *   **[V] Vendor:** Gray items or gear whose direct merchant sell value safely outclasses active Auction House listings.
    *   **[A] Auction House:** High-value marketplace items that clear deposit risks and fee thresholds based on active data.
    *   **[D] Disenchant:** Contextual suggestions for characters with the Enchanting profession when projected materials yield a reliable profit.
    *   **[Q] Quest:** Highlights active quest inventory items with a distinct border to prevent accidental deletion.
    *   **[S] Soulbound:** Displays a subtle label over soulbound equipment items for easy gear progression tracking.
*   **Bagnon Sorting Fix:** Features a native 3.3.5a asynchronous bag sorter that safely orders your backpack by rarity, type, and name without triggering interface locks.
*   **Deep Auctionator Integration:** Seamlessly cross-references real-time 24-hour database prices, cutting out deposit risks automatically.

---

## ⚙️ In-Game Configuration

BagTags features a full graphical interface in the native WoW Options menu to easily toggle specific tags on or off to suit your playstyle. It also includes a draggable minimap shortcut supporting Left-Click (Open Options) and Right-Click (Trigger Bag Sort).

![BagTags Configuration Panel](images/02.png)

---

## 🛠️ Chat Commands & Reports

Type `/bg` or `/bagtags` followed by a sub-command to run real-time inventory audits directly in your chat frame. You can also view available features inside the dedicated in-game sub-panel.

![BagTags Documentation and Reports](images/03.png)

| Command | Action |
| :--- | :--- |
| `/bg` | Displays the help menu with all available usage options. |
| `/bg vendor` | Performs an analysis on all merchantable junk and safe-to-vendor gear, displaying total value. |
| `/bg mats` | Generates an immediate breakdown of your crafting stock and raw materials audit. |
| `/bg ah` | Lists all high-valuation targets currently viable for active Auction House trades. |
| `/bg sort` | Triggers the native asynchronous container sorting routine manually. |
| `/bg debug` | Troubleshoots internal database cross-reference bindings on your main bag's first slot. |

---

## 📦 Installation

1. Download the latest release of **BagTags**.
2. Extract the folder into your WoW directory: `Interface\AddOns\`.
3. Ensure the folder name is exactly `BagTags`.
4. Log into the game, make sure "Load out of date AddOns" is checked, and enjoy!

---

## ⚙️ Requirements & Compatibility

*   **Game Version:** WoW Client 3.3.5a
*   **Supported AddOns:** Fully compatible with the standard Blizzard UI and **Bagnon**.
*   **Recommended AddOns:** **Auctionator** (required for active market pricing, `[A]` and `[D]` tags).

---

## Dependencies

This section contains information about the required add-ons and related libraries, along with frequently asked questions regarding their compatibility with the Project Ascension platform.

### General Information
To ensure proper functionality of modifications in the Project Ascension environment, it is required to have the assigned dependencies in the correct versions dedicated to this platform[cite: 7].

---

### Frequently Asked Questions (FAQ)

#### 1. What are the required dependencies for the Auctionator add-on?
The **Auctionator (Version: 2.9.9)** add-on, specifically modified for Ascension.gg, requires the following side modules to function properly[cite: 7]:
* **Auctionator_Pricing_History** – responsible for saving price history and generating sales statistics[cite: 7, 8].
* **Auctionator_Price_Database** – the main database storing information from auction house scans[cite: 7].

#### 2. How do I know if the add-on versions are intended for Project Ascension?
The versions listed below have been adapted to the server's unique mechanics (such as removing *Bloodforged* item tags or random suffixes)[cite: 7, 8]:
* **Auctionator** — Version **2.9.9 (Ascension Modified)**[cite: 7]
* *[Space for the second add-on / Main mod]* — Version **[Insert second add-on version] (Ascension Edition)**

All official versions for Project Ascension feature appropriate code modifications (e.g., handling specific filters in the `Auctionator.lua` file) and modified `.toc` files tailored for the 3.3.5 game client (Interface: 30300) running on this server[cite: 7, 8].

#### 3. Will older or standard WotLK versions of the Auctionator add-on work?
It is not recommended to use standard versions of the Auctionator add-on for version 3.3.5a. The **2.9.9 version for Ascension** includes unique fixes (e.g., functions like `AUCTIONATOR_ROMOVE_BLOOFORGED` and `AUCTIONATOR_ROMOVE_SUFFIX`), without which the add-on may throw Lua errors when scanning unique equipment with variable stats[cite: 7, 8].

#### 4. Are databases (SavedVariables) from standard WotLK compatible?
Due to differences in item structures on Project Ascension, it is highly recommended to delete old database files (`AUCTIONATOR_PRICE_DATABASE`) before installing the dedicated version[cite: 7] to avoid conflicts when calculating suggested prices.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 📝 Credits & Authors

*   **Author:** grombor
*   **Version:** 0.7.3
*   *Feedback and bug reports are welcome via GitHub Issues or Discord!*