# Raid Cooldown Announcer (RCA) - 3.3.5a Addon

## Overview

Raid Cooldown Announcer (RCA) is a custom World of Warcraft addon designed for the **3.3.5a client**. Its primary purpose is to announce the usage of specific, important raid or party cooldowns in the appropriate chat channel (Party or Raid), helping group members track key abilities during encounters.

This addon was specifically developed and tested on the **'Onyxia' private server (Warmane)** during its TBC phase, which explains some default spell choices (e.g., "Blessing of Protection"). However, it is built using standard 3.3.5a APIs and should be **compatible with most 3.3.5a compliant servers**, though customization of the tracked spell list might be necessary depending on the server's content phase or custom changes.

## Key Features

*   **Automatic Group Detection:** Intelligently detects whether you are in a Party or a Raid.
*   **Dynamic Channel Output:** Automatically sends announcements to `/p` (Party) or `/r` (Raid) chat based on your current group type.
*   **Configurable Activation:**
    *   Option to **prompt the user** to activate RCA for the current session upon joining a group.
    *   Option to **auto-activate** based on the master enable toggle when joining a group.
    *   Master enable/disable toggle via options panel or slash commands.
*   **Customizable Spell List:**
    *   Comes with a default list of common utility spells (Innervate, Rebirth, Blessings, Fear Ward, Soulstone).
    *   Easily **add or remove spells** via the in-game configuration panel. *(Note: Requires exact, case-sensitive spell names as they appear in the combat log)*.
*   **Filtering Options:**
    *   Announce **only your own casts**.
    *   Announce **only casts targeted on you**.
*   **Duplicate Prevention:** Avoids spamming chat by ignoring rapid, duplicate events for the same spell cast.
*   **Configuration Panel:**
    *   Easy-to-use settings panel accessed via `/rca config` or Interface -> AddOns -> RCA.
    *   Includes status display showing Master/Session state and target channel.
    *   Options for toggling features, managing spells, and enabling debug mode.
*   **Profile Management:** Uses AceDBProfiles for creating, managing, copying, and resetting configuration profiles.
*   **Lightweight:** Built on the Ace3 framework, commonly used by many popular addons.

## Configuration & Usage

1.  **Installation:** Place the `RaidCooldownAnnouncer` folder into your `Interface\AddOns\` directory.
2.  **Dependencies:** Requires the **Ace3 library** to be installed or provided by another loaded addon (e.g., ElvUI, Details!, WeakAuras, etc.).
3.  **Accessing Options:**
    *   Type `/rca config` in chat.
    *   Navigate to ESC -> Interface -> AddOns -> RCA.
4.  **Basic Commands:**
    *   `/rca`: Shows status and available commands.
    *   `/rca on`: Enables the addon (Master Toggle).
    *   `/rca off`: Disables the addon (Master Toggle).
    *   `/rca status`: Prints current status to chat.
    *   `/rca test`: Sends a test announcement to the current auto-detected channel (if active).
    *   `/rca debug`: Toggles session-only debug messages.
5.  **Initial Setup:** By default, the addon Master Toggle is ON, and it will ask you if you want to activate announcements when you join a group. Configure the "Ask to activate" option and the tracked spell list in the options panel to suit your needs.

## Compatibility Notes

*   **Client:** WoW 3.3.5a
*   **Server:** Designed for 3.3.5a servers. Tested on Onyxia (Warmane TBC content). Spell names/IDs may differ on servers running different expansion content (e.g., WotLK content might use "Hand of Protection" instead of "Blessing of Protection"). Adjust the tracked spell list accordingly. Combat log event behavior might vary slightly on different private server cores.

## Author

*   otusa (with heavy assistance of various AI models)
