import { writeFile, mkdir } from "node:fs/promises";
import { createHyperSubLayers, createSubLayer } from "./utils.mjs";
const rules = [
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
    // https://github.com/pqrs-org/Karabiner-Elements/issues/2880#issuecomment-1774847928
    {
        description: "Temporary Fix for sleep issue",
        manipulators: [
            {
                type: "basic",
                from: {
                    key_code: "escape",
                },
                to_if_alone: [
                    {
                        key_code: "escape",
                    },
                ],
            },
        ],
    },
    createSubLayer("right_option", "Media Commands Sublayer", {
        s: {
            description: "Play/Pause",
            to: [
                {
                    key_code: "play_or_pause",
                },
            ],
        },
        d: {
            description: "Next",
            to: [
                {
                    key_code: "fastforward",
                },
            ],
        },
        a: {
            description: "Previous",
            to: [
                {
                    key_code: "rewind",
                },
            ],
        },
    }),
    ...createHyperSubLayers({
        // search via
        o: {
            g: {
                description: "Github Repository Search",
                to: [
                    {
                        key_code: "1",
                        modifiers: ["right_option", "right_command", "right_shift"],
                    },
                ],
            },
            a: {
                description: "Arc History Search",
                to: [
                    {
                        key_code: "2",
                        modifiers: ["right_option", "right_command", "right_shift"],
                    },
                ],
            },
            k: {
                description: "Kagi Search",
                to: [
                    {
                        key_code: "3",
                        modifiers: ["right_option", "right_command", "right_shift"],
                    },
                ],
            },
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
        // shortcuts
        c: {
            description: "Clipboard History",
            to: [
                {
                    key_code: "c",
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
        s: {
            description: "Capture Area",
            to: [
                {
                    key_code: "4",
                    modifiers: ["right_option", "right_command", "right_shift"],
                },
            ],
        },
        a: {
            e: {
                description: "Improve English Text",
                to: [
                    {
                        key_code: "e",
                        modifiers: ["right_option", "right_command", "right_shift"],
                    },
                ],
            },
            r: {
                description: "Improve Russian Text",
                to: [
                    {
                        key_code: "r",
                        modifiers: ["right_option", "right_command", "right_shift"],
                    },
                ],
            },
            n: {
                description: "Continue Conversation",
                to: [
                    {
                        key_code: "n",
                        modifiers: ["right_option", "right_command", "right_shift"],
                    },
                ],
            },
        },
    }),
];
const fileContent = JSON.stringify({
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
}, null, 2);
const outputFolder = "./dist";
const outputFile = `${outputFolder}/karabiner.json`;
await mkdir(outputFolder, { recursive: true });
await writeFile(outputFile, fileContent, "utf8");
