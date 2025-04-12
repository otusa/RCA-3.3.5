-- Create a name for our addon's code structure
local addonName = "RaidCooldownAnnouncer"
local addon = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")

-- Default settings table
local defaults = {
    profile = {
        enabled = true,
        askOnGroupJoin = true,
        -- Add the tracked spells table here
        trackedSpells = {
            ["Innervate"] = true,
            ["Rebirth"] = true,
            ["Blessing of Freedom"] = true,
            ["Blessing of Protection"] = true,
            ["Fear Ward"] = true,
            ["Soulstone Resurrection"] = true,
        },
        announceMyCastsOnly = false,
        announceOnMeOnly = false,
    }
}

-- Track which spells we've already announced (Keep this table)
local recentlyAnnounced = {}
local isDebugging = false

-- Clean up the recently announced table every few seconds (Keep this section)
local cleanupTimer = 0
local CLEANUP_INTERVAL = 5 -- seconds
-- Runtime state variables (not saved)
local currentGroupType = nil -- "PARTY", "RAID", or nil
local isActiveSession = false -- Is RCA supposed to be active in the *current* group context?
local currentTargetChannel = nil -- "PARTY", "RAID", or nil
local pendingRefreshTimer = nil




local function RefreshConfig()
    -- If a refresh is already scheduled, don't schedule another one
    if pendingRefreshTimer then return end

    -- Schedule the actual refresh to happen very shortly
    pendingRefreshTimer = addon:ScheduleTimer(function()
        -- Check if AceConfigDialog is loaded NOW
        local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
        -- ADD A CHECK FOR THE METHOD ITSELF:
        if AceConfigDialog and type(AceConfigDialog.Refresh) == "function" then
            AceConfigDialog:Refresh(addonName)
        else
            -- Optional: print a debug message if it's still not loaded after the delay
            if isDebugging then print("|cFFFF9900RCA: AceConfigDialog or :Refresh not ready after delay in RefreshConfig|r") end
        end
        pendingRefreshTimer = nil -- Clear the timer handle once it runs
    end, 0.1) -- Delay by 0.1 seconds
end


-- Define Static Popups for interaction
StaticPopupDialogs["RCA_ENABLE_ON_JOIN"] = {
    text = "You have joined a %s. Enable RCA announcements for this session?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function(self) -- 'Yes' clicked
        if addon.db.profile.enabled then -- Check if master toggle is ON
            isActiveSession = true -- Set runtime variable
            print("|cFF00FF00RCA:|r Session activated by prompt.")
        else
            isActiveSession = false -- Master toggle is off, don't activate
            print("|cFFFF9900RCA:|r Session activation skipped by prompt (Master toggle is off).")
        end
        addon:PrintStatus()
        RefreshConfig() 
    end,
    OnCancel = function(self) -- 'No' clicked
        isActiveSession = false -- Ensure session stays inactive
        print("|cFF00FF00RCA:|r Session kept inactive by prompt.")
        addon:PrintStatus()
        RefreshConfig() 
    end,
    timeout = 0, -- No timeout
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["RCA_SWITCH_TO_RAID"] = {
    text = "Your party converted to a raid. Switch RCA announcements to Raid chat?",
    button1 = "Switch",
    button2 = "Disable RCA",
    OnAccept = function(self) -- 'Switch' clicked
        -- Channel is already updated by UpdateGroupState, just confirm
        print("|cFF00FF00RCA:|r Switched announcements to RAID chat.")
        addon:PrintStatus()
        RefreshConfig() 
    end,
    OnCancel = function(self) -- 'Disable RCA' clicked
        isActiveSession = false
        print("|cFF00FF00RCA:|r Session deactivated on raid conversion by prompt.")
        addon:PrintStatus()
        RefreshConfig() 
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}


-- Called when the addon is first enabled
function addon:OnInitialize()
    -- Load saved settings or use defaults
    -- Note: RCASettings is the global variable WoW creates based on our .toc file
    self.db = LibStub("AceDB-3.0"):New("RCASettings", defaults, "Default")

    -- Register slash command
    self:RegisterChatCommand("rca", "ChatCommand")

    -- Code to create the options panel (will be added below)
    self:SetupOptions()

    print("|cFF00FF00RCA:|r Addon Initialized. Type /rca for options.")
    self:PrintStatus()
end

-- Called when the addon is enabled or player logs in
function addon:OnEnable()
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", "CombatLogHandler")
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "UpdateGroupState")
    self:RegisterEvent("PARTY_MEMBERS_CHANGED", "UpdateGroupState")
    self:RegisterEvent("RAID_ROSTER_UPDATE", "UpdateGroupState")
    self:RegisterEvent("PARTY_CONVERTED_TO_RAID", "UpdateGroupState")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateGroupState")
    self:UpdateGroupState("OnEnable") -- Run initial check
    print("|cFF00FF00RCA:|r Announcer " .. (self.db.profile.enabled and "Enabled" or "Disabled"))
    self.cleanupTimerRef = self:ScheduleRepeatingTimer("CleanupRecentAnnouncements", CLEANUP_INTERVAL)
end

-- Called when the addon is disabled
function addon:OnDisable()
    self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self:UnregisterEvent("GROUP_ROSTER_UPDATE")
    self:UnregisterEvent("PARTY_MEMBERS_CHANGED")
    self:UnregisterEvent("RAID_ROSTER_UPDATE")
    self:UnregisterEvent("PARTY_CONVERTED_TO_RAID")
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    print("|cFF00FF00RCA:|r Announcer Disabled")
    if self.cleanupTimerRef then
        self:CancelTimer(self.cleanupTimerRef)
        self.cleanupTimerRef = nil
    end
end

-- Function to print current status
function addon:PrintStatus()
    print("|cFF00FF00[RCA] Status:|r")
    print("Master Toggle: " .. (self.db.profile.enabled and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"))
    print("Current Session: " .. (isActiveSession and "|cFF00FF00ACTIVE|r" or "|cFFFF0000INACTIVE|r"))
    local channelString = "|cFFFFFFFFNone|r" -- Default white "None"
    if currentTargetChannel then
        if currentTargetChannel == "PARTY" then
            channelString = "|cFF0070DEPARTY|r" -- Blueish
        elseif currentTargetChannel == "RAID" then
            channelString = "|cFFFF7D0ARAID|r" -- Orange
        else
            channelString = "|cFFFFFFFF"..currentTargetChannel.."|r" -- Fallback to white if unexpected value
        end
    end
    print("Target Channel: " .. channelString) -- Print the formatted string

    print("Debug Mode: " .. (isDebugging and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r") .. " (Session Only)")
end

-- Function to handle group composition changes
function addon:UpdateGroupState(source) -- Added 'source' for potential debugging
    if isDebugging then -- Check if debug is enabled FIRST
        print("|cFFFF00FF[RCA DEBUG] UpdateGroupState called by: " .. (source or "Unknown Source") .. "|r")
    end
    local wasActive = isActiveSession
    local oldGroupType = currentGroupType

    -- Determine current group status
    local inRaid = (type(IsInRaid) == "function" and IsInRaid()) or false
        local numGroupMembers = (type(GetNumSubgroupMembers) == "function" and GetNumSubgroupMembers()) or 0
            local inParty = not inRaid and (numGroupMembers > 0) -- If not in raid, check if we have group members
            
            -- Adjust the debug print to show the new variable
            if isDebugging then
                print(string.format("|cFFFF00FF[RCA DEBUG] UpdateGroupState: IsInRaid()=%s, GetNumSubgroupMembers()=%d -> inParty=%s|r", tostring(inRaid), numGroupMembers, tostring(inParty)))
            end
        
            -- >> INSERT THIS MISSING BLOCK << --
            local newGroupType = nil -- Define them here now
            local newChannel = nil
            if inRaid then
                newGroupType = "RAID"
                newChannel = "RAID"
            elseif inParty then
                newGroupType = "PARTY"
                newChannel = "PARTY"
            -- else they remain nil (correct for solo)
            end
            -- >> END OF INSERTED BLOCK << --
        
            -- Update state variables
            currentGroupType = newGroupType -- This will now have the correct value or nil
            currentTargetChannel = newChannel -- This will now have the correct value or nil

    if isDebugging then
        print(string.format("|cFFFF00FF[RCA DEBUG] UpdateGroupState: currentGroupType=%s, Checking master enabled=%s |r",
            tostring(currentGroupType), tostring(self.db.profile.enabled)))
    end
    -- Now set the isActiveSession based on the check:
    if oldGroupType == nil and currentGroupType ~= nil then -- Joining a group (Party or Raid)
        if self.db.profile.askOnGroupJoin then
            local displayGroupName = currentGroupType:sub(1,1):upper() .. currentGroupType:sub(2):lower()
            StaticPopup_Show("RCA_ENABLE_ON_JOIN", displayGroupName)
        else
            -- Activate automatically based on master toggle
            isActiveSession = self.db.profile.enabled
            if isActiveSession then
                 print("|cFF00FF00RCA:|r Session auto-activated for " .. currentGroupType)
                 addon:PrintStatus()
            end
        end
    elseif oldGroupType == "PARTY" and currentGroupType == "RAID" then -- Converting Party to Raid
        if isActiveSession then -- Only ask if it was active in the party
             StaticPopup_Show("RCA_SWITCH_TO_RAID")
             -- Note: isActiveSession might be set to false by the popup callback
        else
            -- If it wasn't active in party, don't automatically activate for raid unless ask=false
            if not self.db.profile.askOnGroupJoin then
                -- Activate automatically based on master toggle (NO CHANGE NEEDED HERE - logic is already correct)
                isActiveSession = self.db.profile.enabled
                if isActiveSession then
                     print("|cFF00FF00RCA:|r Session auto-activated for RAID after conversion.")
                     addon:PrintStatus()
                end
           end
        end
    elseif oldGroupType ~= nil and currentGroupType == nil then -- Leaving a group
        if isActiveSession then -- Only print if it was active
             print("|cFF00FF00RCA:|r Session deactivated (Left Group).")
        end
        isActiveSession = false -- Always deactivate session on leaving group
        -- We don't clear currentTargetChannel here, CombatLog handler check is enough
    elseif oldGroupType == currentGroupType and not wasActive and self.db.profile.enabled and isActiveSession then
         -- This covers the case where the user toggled ON while already in a group
         -- or potentially if 'ask' is false and group type didn't change but master was enabled
         print("|cFF00FF00RCA:|r Session Activated for " .. currentGroupType)
         addon:PrintStatus()
    -- Optionally handle other transitions if needed (e.g., Raid -> Party)
    end
    RefreshConfig()
end

-- Function to define and register options
function addon:SetupOptions()
    local options = {
        name = "RCA", -- Addon name in the options panel
        handler = addon, -- Where functions are found (our addon object)
        type = 'group',
        args = {
            enabled = {
                type = 'toggle',
                name = "Enable Announcements",
                desc = "Globally enable or disable raid announcements.",
                order = 1,
                get = function(info) return addon.db.profile.enabled end,
                set = function(info, value)
                    -- Set the master toggle value FIRST
                    addon.db.profile.enabled = value
                    print("|cFF00FF00[RCA]|r Announcements Master Toggle " .. (value and "Enabled" or "Disabled"))
    
                    -- Update session state based on new master toggle value
                    if value then
                        -- Trying to enable
                        if currentGroupType then -- Only activate session if in a group
                            isActiveSession = true
                            print("|cFF00FF00[RCA]|r Session Activated by toggle (currently in " .. currentGroupType .. ")")
                        end
                        addon:OnEnable() -- Ensure events are registered etc.
                    else
                        -- Trying to disable
                        if isActiveSession then
                             print("|cFF00FF00[RCA]|r Session Deactivated by toggle.")
                        end
                        isActiveSession = false -- Always deactivate session if master is off
                        addon:OnDisable() -- Ensure events are unregistered etc.
                    end
                    -- Don't call UpdateGroupState here anymore, we handled the logic above
                    addon:PrintStatus() -- Show updated status
                    RefreshConfig() -- Add this
                end,
            },
            statusHeader = {
                order = 1.1, -- Order it just below the main toggle
                type = "header",
                name = "Current Status",
            },
            statusDisplay = {
                order = 1.2,
                type = "description",
                name = function() -- Use a function to generate the text dynamically
                    local statusText = ""
                    -- Master Toggle Status
                    if addon.db.profile.enabled then
                        statusText = statusText .. "Master: |cFF00FF00Enabled|r"
                    else
                        statusText = statusText .. "Master: |cFFFF0000Disabled|r"
                    end
    
                    -- Session Status
                    if isActiveSession then
                        statusText = statusText .. "  |  Session: |cFF00FF00ACTIVE|r"
                    else
                        statusText = statusText .. "  |  Session: |cFFFF0000INACTIVE|r"
                    end
    
                    -- Channel Status (only show if session is active)
                    if isActiveSession and currentTargetChannel then
                        local channelColor = "|cFFFFFFFF" -- Default white
                        if currentTargetChannel == "PARTY" then
                            channelColor = "|cFF0070DE" -- Blueish
                        elseif currentTargetChannel == "RAID" then
                            channelColor = "|cFFFF7D0A" -- Orange
                        end
                        statusText = statusText .. "  |  Target: " .. channelColor .. currentTargetChannel .. "|r"
                    else
                         statusText = statusText .. "  |  Target: None"
                    end
    
                    return statusText
                end,
                width = "full", -- Make it take full width
                fontSize = "medium", -- Optional: adjust font size
            },
            debug = {
                type = 'toggle',
                name = "Debug Mode", -- Changed name slightly
                desc = "Print detailed messages to chat for troubleshooting. Resets to off on login/reload.", -- Updated desc
                order = 2,
                get = function(info) return isDebugging end, -- Use local variable
                set = function(info, value)
                    isDebugging = value -- Use local variable
                    print("|cFF00FF00[RCA]|r Debug mode " .. (value and "enabled" or "disabled") .. " for this session.")
                end,
            },
            askOnGroupJoin = {
                type = 'toggle',
                name = "Ask to activate",
                desc = "If checked, RCA will ask to activate when you join a group. Clicking 'Yes' requires the Master Toggle ('Enable Announcements') to also be ON for the session to become active.\n\nIf unchecked, RCA activates automatically when joining a group, but only if the Master Toggle is also ON.",
                order = 3,
                get = function(info) return addon.db.profile.askOnGroupJoin end,
                set = function(info, value) addon.db.profile.askOnGroupJoin = value end,
            },
        announceMyCastsOnly = {
            order = 4, -- Adjust order as needed
            type = 'toggle',
            name = "Announce My Casts Only",
            desc = "If checked, only spells you cast yourself will be announced.",
            get = function(info) return addon.db.profile.announceMyCastsOnly end,
            set = function(info, value)
                addon.db.profile.announceMyCastsOnly = value
                RefreshConfig() -- Refresh in case other options depend on this later
            end,
            width = "full", -- Take full width for clarity
        },
        announceOnMeOnly = {
            order = 5, -- Adjust order as needed
            type = 'toggle',
            name = "Announce Casts on Me Only",
            desc = "If checked, only spells cast directly on you will be announced.",
            get = function(info) return addon.db.profile.announceOnMeOnly end,
            set = function(info, value)
                addon.db.profile.announceOnMeOnly = value
                RefreshConfig() -- Refresh in case other options depend on this later
            end,
            width = "full",
        },
            test = {
                type = 'execute',
                name = "Send Test Announcement",
                desc = "Sends a test message.",
                order = 11,
                func = "SendTestAnnouncement", -- Calls addon:SendTestAnnouncement()
            },
            spellsHeader = {
                order = 20,
                type = "header",
                name = "Tracked Spells",
            },
            addSpellGroup = { -- Group input and button together visually
                order = 22,
                type = "group",
                name = "Add Spell",
                inline = true, -- Put elements side-by-side
                args = {
                    addSpellInput = {
                        order = 1,
                        type = "input",
                        name = "Spell Name",
                        desc = "Enter the exact spell name (case sensitive!) to add.",
                        width = "normal", -- Adjust width as needed
                        -- We need get/set to store the input temporarily before adding
                        get = function(info) return addon.addSpellName or "" end,
                        set = function(info, value) addon.addSpellName = value end,
                    },
                    addSpellButton = {
                        order = 2,
                        type = "execute",
                        name = "Add",
                        func = "AddTrackedSpell", -- Calls addon:AddTrackedSpell()
                        width = "half",
                    },
                }
            },
            removeSpellGroup = { -- Group dropdown and button
                order = 23,
                type = "group",
                name = "Remove Spell",
                inline = true,
                args = {
                    removeSpellSelect = {
                        order = 1,
                        type = "select",
                        name = "Select to remove",
                        desc = "Choose a spell from the list to remove.",
                        width = "normal",
                        values = function() -- Function to populate dropdown
                            local spellsTable = {}
                            local sortedSpells = {}
                            for name, _ in pairs(addon.db.profile.trackedSpells) do
                                table.insert(sortedSpells, name)
                            end
                            table.sort(sortedSpells)
                            for _, spellName in ipairs(sortedSpells) do
                                spellsTable[spellName] = spellName -- Key and Value are the spell name
                            end
                            if #sortedSpells == 0 then
                                return { [""] = "No spells to remove" }
                            end
                            return spellsTable
                        end,
                        -- Store the selection temporarily
                        get = function(info) return addon.removeSpellSelection end,
                        set = function(info, value) addon.removeSpellSelection = value end,
                    },
                    removeSpellButton = {
                        order = 2,
                        type = "execute",
                        name = "Remove",
                        func = "RemoveTrackedSpell", -- Calls addon:RemoveTrackedSpell()
                        width = "half",
                        disabled = function() -- Disable button if no spell selected or list empty
                            return not addon.removeSpellSelection or addon.removeSpellSelection == "" or not next(addon.db.profile.trackedSpells)
                        end,
                    },
                }
            },
        },
    }

    -- Register the options table with AceConfig
    LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, options)

    -- Add our options panel to the Blizzard Interface Addons screen
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName, "RCA") -- Use "RCA" as the display name
end


function addon:AddTrackedSpell()
    local spellName = self.addSpellName -- Get value from temporary storage used by input widget
    if spellName and spellName ~= "" then
        spellName = spellName:match("^%s*(.-)%s*$") -- Trim whitespace
        if spellName ~= "" then
            -- Basic check: maybe avoid adding duplicates, though table prevents issues
            if not self.db.profile.trackedSpells[spellName] then
                self.db.profile.trackedSpells[spellName] = true
                print("|cFF00FF00[RCA]|r Added '" .. spellName .. "' to tracked spells.")
                self.addSpellName = "" -- Clear the input field storage
                RefreshConfig() -- Update the options panel display
            else
                print("|cFFFF9900[RCA]|r Spell '" .. spellName .. "' is already tracked.")
                self.addSpellName = "" -- Still clear input
            end
        else
             print("|cFFFF0000[RCA]|r Cannot add empty spell name.")
        end
    else
        print("|cFFFF0000[RCA]|r Please enter a spell name to add.")
    end
end



function addon:RemoveTrackedSpell()
    local spellName = self.removeSpellSelection -- Get value from dropdown selection storage
    if spellName and spellName ~= "" and self.db.profile.trackedSpells[spellName] then
        self.db.profile.trackedSpells[spellName] = nil -- Remove by setting to nil
        print("|cFF00FF00[RCA]|r Removed '" .. spellName .. "' from tracked spells.")
        self.removeSpellSelection = nil -- Clear the selection storage
        RefreshConfig() -- Update the options panel display
    else
        print("|cFFFF0000[RCA]|r Could not remove spell. Select a valid spell from the list.")
    end
end




-- Function to handle sending a test message
function addon:SendTestAnnouncement()
    -- Check the MASTER toggle first - test only works if addon could be enabled
    if not self.db.profile.enabled then
         print("|cFFFF0000[RCA] Enable announcements first (/rca on or via Interface Options) to send a test.|r")
         return
    end

    -- Now check if we are actually in a group where it *could* send
    if not isActiveSession or not currentTargetChannel then
        print("|cFFFF9900[RCA]|r Cannot send test announcement. Not currently in an active party or raid session.")
        return
    end

    -- Proceed if session is active and channel is known
    print("|cFF00FF00[RCA] Sending test announcement to " .. currentTargetChannel .. "...|r")
    local playerName = UnitName("player") or "UnknownPlayer"
    local testTarget = "TestTarget"
    local spellName = "Fear Ward"
    local spellId = 6346 -- Example Spell ID for Fear Ward (WotLK)
    local spellLink = GetSpellLink(spellId) or ("[" .. spellName .. "]")
    -- Use the determined channel:
    SendChatMessage("Test Announcement: " .. playerName .. " cast " .. spellLink .. " on " .. testTarget .. "!", currentTargetChannel)

end



















-- NEW Slash command handler using AceConsole-3.0
function addon:ChatCommand(input)
    input = string.lower(input or "")

    if input == "test" then
        self:SendTestAnnouncement()
    elseif input == "debug" then
        -- Toggle debug mode using the options setter logic
        isDebugging = not isDebugging -- Use local variable
        print("|cFF00FF00[RCA]|r Debug mode " .. (isDebugging and "enabled" or "disabled") .. " for this session.")
    elseif input == "on" then
        if not self.db.profile.enabled then
            self.db.profile.enabled = true -- Set master toggle
            print("|cFF00FF00[RCA]|r Announcements Master Toggle Enabled")
            if currentGroupType then -- If in group, also activate session
                isActiveSession = true
                print("|cFF00FF00[RCA]|r Session Activated by command (currently in " .. currentGroupType .. ")")
            end
            self:OnEnable() -- Ensure events etc are handled
            self:PrintStatus()
        else
            print("|cFF00FF00[RCA]|r Announcements Master Toggle already enabled.")
            -- If already enabled, maybe ensure session is active if in group? Optional.
            if currentGroupType and not isActiveSession then
                 isActiveSession = true
                 print("|cFF00FF00[RCA]|r Session reactivated by command (currently in " .. currentGroupType .. ")")
                 self:PrintStatus()
                 RefreshConfig() -- Add this
            end
        end
    elseif input == "off" then
        if self.db.profile.enabled then
            self.db.profile.enabled = false -- Set master toggle
            print("|cFF00FF00[RCA]|r Announcements Master Toggle Disabled")
            if isActiveSession then -- If session was active, announce deactivation
                 print("|cFF00FF00[RCA]|r Session Deactivated by command.")
            end
            isActiveSession = false -- Always deactivate session
            self:OnDisable() -- Ensure events etc are handled
            self:PrintStatus()
            RefreshConfig() -- Add this
        else
            print("|cFF00FF00[RCA]|r Announcements Master Toggle already disabled.")
        end
    elseif input == "forceupdate" then -- Temporary debug command
    if isDebugging then
        print("|cFFFFD100[RCA]|r Forcing group state update...")
    end
    self:UpdateGroupState("ForceUpdateCommand")
    self:PrintStatus() -- Print status immediately after
    elseif input == "config" then
         -- Open the Blizzard options panel directly to our addon's settings
         InterfaceOptionsFrame_OpenToCategory("RCA")
         -- Optional: If you have a standalone AceGUI window later, you'd open it here.
    elseif input == "status" then
        self:PrintStatus()
    else
         -- Show help
         print("|cFF00FF00[RCA] Commands:|r")
         print("/rca on - Enable spell announcements")
         print("/rca off - Disable spell announcements")
         print("/rca test - Run a test announcement")
         print("/rca debug - Toggle debug messages")
         print("/rca config - Open configuration panel")
         print("/rca status - Show current status")
         self:PrintStatus()
    end
end





-- Define the combat log handler function attached to the addon object
function addon:CombatLogHandler(event, ...) -- Note: 'self' is now implicit
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        -- Only process if announcements are enabled via saved settings
        if not isActiveSession then return end

        local timestamp, subEvent, sourceGUID, sourceName, sourceFlags, destGUID, destName = ...
        local spellId, spellName

        if subEvent:find("SPELL") then
            -- Use correct indices for 3.3.5 combat log event
            if subEvent == "SPELL_CAST_SUCCESS" or subEvent == "SPELL_CAST_START" or subEvent == "SPELL_SUMMON" then
               spellId, spellName = select(9, ...)
            elseif subEvent == "SPELL_AURA_APPLIED" or subEvent == "SPELL_AURA_REMOVED" or subEvent == "SPELL_AURA_APPLIED_DOSE" or subEvent == "SPELL_AURA_REMOVED_DOSE" or subEvent == "SPELL_AURA_BROKEN_SPELL" then
               spellId, spellName = select(9, ...)
            -- Add other subEvents if needed and find their spellId/Name position
            -- Example: SPELL_ENERGIZE might have spell info at different parameters
            end
        end

        -- Print debug info if enabled (using saved setting)
        if isDebugging and spellName then
             print(string.format(
                 "|cFF00FF00[RCA Debug]|r Event: %s | Spell: %s (%s) | Source: %s | Target: %s",
                 subEvent or "nil",
                 spellName or "nil",
                 spellId or "nil",
                 sourceName or "nil",
                 destName or "nil"
             ))
        end

        -- Check for valid events for tracked spells
        if spellName and self.db.profile.trackedSpells[spellName] and
           (subEvent == "SPELL_CAST_SUCCESS" or subEvent == "SPELL_AURA_APPLIED") then

            -- Create a unique key for this spell cast to prevent duplicates
            local castKey = (sourceName or "nil") .. "-" .. spellName .. "-" .. (destName or "nil")

            -- Check if we've already announced this recently
            if recentlyAnnounced[castKey] then
                if isDebugging then
                    print("|cFFFF9900[RCA]|r Skipping duplicate announcement for: " .. castKey)
                end
                return
            end

            -- Mark this spell as recently announced
            recentlyAnnounced[castKey] = GetTime()

            if isDebugging then
                print(string.format("|cFFFF9900[RCA]|r Detected tracked spell: %s", spellName))
            end

            if self.db.profile.announceMyCastsOnly then
                -- Check if the source is NOT the player
                local isPlayer = type(UnitIsUnit) == "function" and UnitIsUnit("player", sourceName)
                if not isPlayer then
                    if isDebugging then
                        print("|cFFFF9900[RCA]|r Skipping announcement: 'Announce My Casts Only' is enabled and source (" .. (sourceName or "nil") .. ") is not player.")
                    end
                    return -- Stop processing this event
                end
            end

        if self.db.profile.announceOnMeOnly then
            local isPlayerTarget = type(UnitIsUnit) == "function" and UnitIsUnit("player", destName)
            if not isPlayerTarget then
                 if isDebugging then
                    print("|cFFFF9900[RCA]|r Skipping announcement: 'On Me Only' enabled and target (" .. (destName or "nil") .. ") is not player.")
                end
                return -- Stop processing this event
            end
        end

            -- Make sure we have both source and target names
            if sourceName and destName then
                -- >> START REPLACEMENT << --
                -- Check if caster is in our current group using the known group type
                local isInGroup = false
                if currentGroupType then -- Use the type determined by UpdateGroupState ("RAID" or "PARTY")
                    local unitPrefix = string.lower(currentGroupType) -- Get "raid" or "party"
                    local numMembers = GetNumGroupMembers() -- Get total members in raid or party
                    for i = 1, numMembers do
                        -- Construct the unit token like "raid1" or "party1"
                        -- Important: Check if UnitName exists before calling, just in case
                        local memberName = type(UnitName) == "function" and UnitName(unitPrefix .. i)
                        if memberName and memberName == sourceName then
                            isInGroup = true
                            break -- Found them, no need to loop further
                        end
                    end
                end
    
                -- If still not found in the group roster, check if the source is the player
                -- (handles cases where the player isn't fully registered in the roster yet, maybe?)
                if not isInGroup and (type(UnitIsUnit) == "function" and UnitIsUnit("player", sourceName)) then
                    isInGroup = true
                    -- No need to re-check groupType here, we already know we're in an active session
                end


                if isInGroup then
                    -- Create spell link or fallback
                    local spellLink = spellId and GetSpellLink(spellId) or ("[" .. spellName .. "]")

                    -- Format and send the message
                    local message = string.format("%s cast %s on %s!", sourceName, spellLink, destName)
                    if currentTargetChannel then
                        if isDebugging then
                            print("|cFF00FF00[RCA]|r Sending announcement to " .. currentTargetChannel .. ": " .. message)
                        end
                        SendChatMessage(message, currentTargetChannel)
                    elseif isDebugging then
                        -- This case should ideally not happen if isActiveSession is true, but safety check
                         print("|cFFFF9900[RCA]|r Session active but no target channel set. Cannot send announcement.")
                    end

                elseif isDebugging then
                    print("|cFFFF0000[RCA]|r Source not in group: " .. (sourceName or "unknown"))
                end
            elseif isDebugging then
                print("|cFFFF0000[RCA]|r Missing source or destination name for " .. (spellName or "unknown spell"))
            end
        end
    end
end


function addon:CleanupRecentAnnouncements()
    local now = GetTime()
    local count = 0
    for key, timestamp in pairs(recentlyAnnounced) do
        if now - timestamp > 3 then -- Use 3 seconds like before
            recentlyAnnounced[key] = nil
            count = count + 1
        end
    end
    -- Optional debug message:
    -- if self.db.profile.debug and count > 0 then
    --     print("[RCA Debug] Cleaned up", count, "old announcements.")
    -- end
end

