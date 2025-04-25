**IMPORTANT INSTALLATION NOTE:** When downloading from GitHub (e.g., via "Download ZIP"), the main folder inside the ZIP might have `-main` or similar appended to its name. **You MUST rename this folder** to exactly `RaidCooldownAnnouncer` before placing it in your AddOns directory.

The correct path should look like this:
`World_of_Warcraft_Folder\Interface\AddOns\RaidCooldownAnnouncer\`
*(Inside this folder should be the `.toc` and `.lua` files)*

# RaidCooldownAnnouncer (RCA) for WotLK 3.3.5


Tired of asking "Who used Innervate?" or missing that clutch BoP? This simple addon announces key raid/party cooldowns when they're used, right in chat. No frills, just the info you need.

## What it Does

*   **Announces Spells:** Tracks specific cooldowns (Innervate, Rebirth, Blessings, Fear Ward, Soulstone Res by default) when used by group members.
*   **Smart Channel:** Automatically announces to `PARTY` chat in a party, and `RAID` chat in a raid. Handles party-to-raid conversion.
*   **Configurable:**
    *   Easily add/remove spells to track via the options panel.
    *   Toggle announcements on/off (`/rca on`, `/rca off`).
    *   Optionally announce *only* your own casts.
    *   Optionally announce *only* casts targeted on you.
    *   Ask-on-join prompt (or auto-enable if you prefer).
*   **Simple Interface:** Access options via `/rca config` (Interface Options -> AddOns -> RCA) or use slash commands.
*   **Duplicate Prevention:** Won't spam chat if the same spell/target combo happens multiple times quickly.

## Default Tracked Spells (You can change these!)

*   Innervate
*   Rebirth
*   Blessing of Freedom
*   Blessing of Protection
*   Fear Ward
*   Soulstone Resurrection

## Basic Usage

*   `/rca` - Shows available commands and current status.
*   `/rca on` / `/rca off` - Enable/disable the addon's announcements.
*   `/rca config` - Opens the options panel.
*   `/rca test` - Sends a test message *if* you're in an active group session.
*   `/rca status` - Shows if RCA is enabled, active for the current session, and target chat channel.
*   `/rca debug` - Toggles debug messages for troubleshooting (session only).

## Installation

1.  Download the latest release (`.zip` file).
2.  Extract the `RaidCooldownAnnouncer` folder.
3.  Place it into your `World of Warcraft\_classic_\Interface\AddOns\` directory.
4.  Make sure it's enabled in the Addons list at your character select screen.

## Compatibility Notes

*   **Client:** WoW 3.3.5a
*   **Server:** Designed for 3.3.5a servers. Tested on Onyxia (Warmane TBC content). Spell names/IDs may differ on servers running different expansion content (e.g., WotLK content might use "Hand of Protection" instead of "Blessing of Protection"). Adjust the tracked spell list accordingly. Combat log event behavior might vary slightly on different private server cores.

## Author

*   otusa (with heavy assistance of various AI models)
