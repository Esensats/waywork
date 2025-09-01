# Waywork

A framework for building [waywall](https://github.com/tesselslate/waywall) configurations for Minecraft speedrunning setups on Linux/Wayland.

## Overview

Waywork provides a structured, modular approach to managing waywall configurations. It abstracts common patterns like resolution switching, scene management, and process orchestration into reusable components, making waywall configs more maintainable and easier to understand.

## Example config

For reference you can look at my config which uses waywork here: [Esensats/waywall-config](https://github.com/Esensats/waywall-config)

## Table of Contents

<!-- @import "[TOC]" {cmd="toc" depthFrom=2 depthTo=6 orderedList=false} -->

<!-- code_chunk_output -->

- [Overview](#overview)
- [Example config](#example-config)
- [Table of Contents](#table-of-contents)
- [Components](#components)
  - [Scene Manager (`scene.lua`)](#scene-manager-scenelua)
  - [Mode Manager (`modes.lua`)](#mode-manager-modeslua)
  - [Key Bindings (`keys.lua`)](#key-bindings-keyslua)
  - [Core Utilities (`core.lua`)](#core-utilities-corelua)
  - [Process Management (`processes.lua`)](#process-management-processeslua)
- [Migration to Waywork](#migration-to-waywork)
  - [Before](#before)
  - [After (Waywork)](#after-waywork)
- [Benefits](#benefits)

<!-- /code_chunk_output -->

## Components

### Scene Manager (`scene.lua`)

Manages visual elements (mirrors, images, text) uniformly with grouping and lifecycle management.

**Features:**

- **Unified Management**: Handle mirrors, images, and text objects through a single interface
- **Grouping**: Organize scene objects into logical groups for batch operations
- **Lazy Loading**: Objects are only created when enabled
- **Dynamic Updates**: Modify object properties at runtime

**Example:**

```lua
local Scene = require("waywork.scene")
local scene = Scene.SceneManager.new(waywall)

-- Register scene objects
scene:register("e_counter", {
    kind = "mirror",
    options = {
        src = { x = 1, y = 37, w = 49, h = 9 },
        dst = { x = 1150, y = 300, w = 196, h = 36 }
    },
    groups = { "thin" },
})

scene:register("eye_overlay", {
    kind = "image",
    path = "/path/to/overlay.png",
    options = { dst = { x = 30, y = 340, w = 700, h = 400 } },
    groups = { "tall" },
})

-- Enable/disable by group
scene:enable_group("thin", true)   -- Enable all "thin" objects
scene:enable_group("tall", false)  -- Disable all "tall" objects

-- Enable/disable individual objects
scene:enable("e_counter", true)
```

### Mode Manager (`modes.lua`)

Orchestrates resolution switching with enter/exit hooks and guard conditions.

**Features:**

- **Resolution Management**: Automatic resolution switching with cleanup
- **Lifecycle Hooks**: `on_enter` and `on_exit` callbacks for mode transitions
- **Toggle Guards**: Conditional guards to prevent accidental mode switches (e.g. pressing F3 + F4 to switch gamemode, but accidentally triggering mode transition instead)
- **State Tracking**: Knows which mode is currently active

**Example:**

```lua
local Modes = require("waywork.modes")
local ModeManager = Modes.ModeManager.new(waywall)

ModeManager:define("thin", {
    width = 340,
    height = 1080,
    on_enter = function()
        scene:enable_group("thin", true)
    end,
    on_exit = function()
        scene:enable_group("thin", false)
    end,
})

ModeManager:define("tall", {
    width = 384,
    height = 16384,
    toggle_guard = function()
        return not waywall.get_key("F3")  -- Prevent toggle during F3 debug
    end,
    on_enter = function()
        scene:enable_group("tall", true)
        waywall.set_sensitivity(tall_sens)
    end,
    on_exit = function()
        scene:enable_group("tall", false)
        waywall.set_sensitivity(0)
    end,
})

-- Toggle modes
ModeManager:toggle("thin")  -- Switch to thin mode
ModeManager:toggle("thin")  -- Switch back to default (0x0)
```

### Key Bindings (`keys.lua`)

Simple utility for building action tables from key mappings.

**Example:**

```lua
local Keys = require("waywork.keys")

local actions = Keys.actions({
    ["*-Alt_L"] = function()
        return ModeManager:toggle("thin")
    end,
    ["*-F4"] = function()
        return ModeManager:toggle("tall")
    end,
    ["Ctrl-E"] = function()
        waywall.press_key("ESC")
    end,
})

config.actions = actions
```

### Core Utilities (`core.lua`)

Low-level utilities used throughout the framework.

**Features:**

- **Toggle**: Boolean state management with callbacks
- **Resettable Timeout**: Timeout that cancels previous invocations
- **Table Operations**: Copy and merge utilities

### Process Management (`processes.lua`)

Utilities for managing external processes with shell command handling.

**Features:**

- **Process Detection**: Check if processes are running using `pgrep`
- **Java JAR Support**: Specialized utilities for launching Java applications
- **Argument Handling**: Proper handling of command arguments as arrays

**Example:**

```lua
local P = require("waywork.processes")

-- Check if a process is running
if P.is_running("firefox") then
    print("Firefox is running")
end

-- Create Java JAR launchers with proper argument handling
local ensure_paceman = P.ensure_java_jar(
    waywall,
    "/usr/lib/jvm/java-24-openjdk/bin/java",
    "/home/user/apps/paceman-tracker.jar",
    {"--nogui"}  -- arguments as array
)("paceman-tracker\\.jar*")  -- process pattern to check

local ensure_ninjabrain = P.ensure_java_jar(
    waywall,
    "/usr/lib/jvm/java-24-openjdk/bin/java",
    "/home/user/apps/ninjabrain-bot.jar",
    {"-Dawt.useSystemAAFontSettings=on"}  -- JVM arguments
)("ninjabrain-bot\\.jar")  -- process pattern to check

-- Use in key bindings
["Ctrl-Shift-P"] = function()
    ensure_ninjabrain() -- ensure Ninjabrain is running
    ensure_paceman() -- ensure Paceman is running
end,
```

## Migration to Waywork

### Before

```lua
-- Scattered mirror management
local make_mirror = function(options)
    local this = nil
    return function(enable)
        if enable and not this then
            this = waywall.mirror(options)
        elseif this and not enable then
            this:close()
            this = nil
        end
    end
end

local mirrors = {
    e_counter = make_mirror({ src = {...}, dst = {...} }),
    thin_pie_all = make_mirror({ src = {...}, dst = {...} }),
    -- ... dozens more
}

-- Manual resolution management
local make_res = function(width, height, enable, disable)
    return function()
        local active_width, active_height = waywall.active_res()
        if active_width == width and active_height == height then
            waywall.set_resolution(0, 0)
            disable()
        else
            waywall.set_resolution(width, height)
            enable()
        end
    end
end
```

### After (Waywork)

```lua
local waywall = require("waywall")

local Scene = require("waywork.scene")
local Modes = require("waywork.modes")
local Keys = require("waywork.keys")

local scene = Scene.SceneManager.new(waywall)
local ModeManager = Modes.ModeManager.new(waywall)

-- Clean object registration
scene:register("e_counter", {
    kind = "mirror",
    options = { src = {...}, dst = {...} },
    groups = { "thin" },
})

-- Declarative mode definitions
ModeManager:define("thin", {
    width = 340,
    height = 1080,
    on_enter = function() scene:enable_group("thin", true) end,
    on_exit = function() scene:enable_group("thin", false) end,
})

-- Simple key mappings
local actions = Keys.actions({
    ["*-Alt_L"] = function() return ModeManager:toggle("thin") end,
})
```

## Benefits

1. **Reduced Boilerplate**: Framework handles object lifecycle, resolution management, and state tracking
2. **Better Organization**: Logical grouping of related functionality
3. **Maintainability**: Clear separation of concerns and declarative configuration
4. **Reusability**: Common patterns abstracted into reusable components
5. **Error Prevention**: Toggle guards and proper state management prevent common issues
6. **Cleaner Code**: Focus on what you want to achieve, not how to implement it
