import { writeFile } from "node:fs/promises";
import { KarabinerRules } from "./types.mjs";
import { createHyperSubLayers, app } from "./utils.mjs";

const rules: KarabinerRules[] = [
    // Define the Hyper key itself
    {
        description: "Hyper Key (⌃⌥⇧⌘)",
        manipulators: [
            {
                description: "Caps Lock -> Hyper Key",
                from: {
                    key_code: "caps_lock",
                },
                to: [
                    {
                        key_code: "left_shift",
                        modifiers: ["left_command", "left_control", "left_option"],
                    },
                ],
                to_if_alone: [
                    {
                        key_code: "escape",
                    },
                ],
                type: "basic",
            },
        ],
    },
    ...createHyperSubLayers({
        // o = "Open" applications
        o: {
            a: app("Arc"),
            s: app("Spotify"),
            w: app("WebStorm"),
            p: app("PyCharm Professional Edition"),
            g: app("GoLand"),
            n: app("Notion"),
            c: app("Warp"),
            t: app("Telegram"),
            m: app("Sublime Merge"),
        },

        // w = "Window" via rectangle.app
        w: {
            left_arrow: {
                description: "Window: Left Half",
                to: [
                    {
                        key_code: "left_arrow",
                        modifiers: ["right_option", "right_command"],
                    },
                ],
            },
            right_arrow: {
                description: "Window: Right Half",
                to: [
                    {
                        key_code: "right_arrow",
                        modifiers: ["right_option", "right_command"],
                    },
                ],
            },
            up_arrow: {
                description: "Window: Top Half",
                to: [
                    {
                        key_code: "up_arrow",
                        modifiers: ["right_option", "right_command"],
                    },
                ],
            },
            down_arrow: {
                description: "Window: Bottom Half",
                to: [
                    {
                        key_code: "down_arrow",
                        modifiers: ["right_option", "right_command"],
                    },
                ],
            },
            return_or_enter: {
                description: "Window: Full Screen",
                to: [
                    {
                        key_code: "return_or_enter",
                        modifiers: ["right_option", "right_command"],
                    },
                ],
            },
            c: {
                description: "Window: Center",
                to: [
                    {
                        key_code: "c",
                        modifiers: ["right_option", "right_command"],
                    },
                ],
            },
            h: {
                description: "Window: Hide",
                to: [
                    {
                        key_code: "h",
                        modifiers: ["right_command"],
                    },
                ],
            },
            i: {
                description: "Window: First Third",
                to: [
                    {
                        key_code: "i",
                        modifiers: ["right_option", "right_command"],
                    },
                ],
            },
            o: {
                description: "Window: Center Third",
                to: [
                    {
                        key_code: "o",
                        modifiers: ["right_option", "right_command"],
                    },
                ],
            },
            p: {
                description: "Window: Last Third",
                to: [
                    {
                        key_code: "p",
                        modifiers: ["right_option", "right_command"],
                    },
                ],
            },
            open_bracket: {
                description: "Window: First Two Thirds",
                to: [
                    {
                        key_code: "open_bracket",
                        modifiers: ["right_option", "right_command"],
                    },
                ],
            },
            close_bracket: {
                description: "Window: Last Two Thirds",
                to: [
                    {
                        key_code: "close_bracket",
                        modifiers: ["right_option", "right_command"],
                    },
                ],
            },
        },

        // r = "Raycast"
        r: {
            c: {
                description: "Clipboard History",
                to: [
                    {
                        key_code: "c",
                        modifiers: ["right_option", "right_command", "right_shift"],
                    },
                ],
            },
            s: {
                description: "Capture Area",
                to: [
                    {
                        key_code: "4",
                        modifiers: ["right_option", "right_command", "right_shift"],
                    },
                ],
            },
            g: {
                description: "AI Chat",
                to: [
                    {
                        key_code: "g",
                        modifiers: ["right_option", "right_command", "right_shift"],
                    },
                ],
            },
        },
    }),
];

const fileContent = JSON.stringify(
    {
        global: {
            show_in_menu_bar: false,
        },
        profiles: [
            {
                name: "Default",
                complex_modifications: {
                    rules,
                },
            },
        ],
    },
    null,
    2,
);

await writeFile("./dist/karabiner.json", fileContent, "utf8");
