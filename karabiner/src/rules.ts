import { writeFile, mkdir } from "node:fs/promises";
import type { KarabinerRules } from "./types.js";
import { createHyperSubLayers, app, createSubLayer, rectangle, open } from "./utils.js";

const rules: KarabinerRules[] = [
    // Define the Hyper key itself
    {
        description: "Hyper Key (⌃⌥⇧⌘)",
        manipulators: [
            {
                description: "Caps Lock -> Hyper Key",
                from: {
                    key_code: "caps_lock",
                    modifiers: {
                        optional: ["any"],
                    },
                },
                to: [
                    {
                        set_variable: {
                            name: "hyper",
                            value: 1,
                        },
                    },
                ],
                to_after_key_up: [
                    {
                        set_variable: {
                            name: "hyper",
                            value: 0,
                        },
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
            g: open("raycast://extensions/raycast/github/search-repositories"),
            a: open("raycast://extensions/the-browser-company/arc/search-history"),
            k: open("raycast://extensions/the-browser-company/arc/search"),
        },

        // w = "Window" via rectangle.app
        w: {
            left_arrow: rectangle("left-half"),
            right_arrow: rectangle("right-half"),
            down_arrow: rectangle("bottom-half"),
            up_arrow: rectangle("top-half"),
            return_or_enter: rectangle("maximize"),
            c: rectangle("center"),
            h: {
                description: "Window: Hide",
                to: [
                    {
                        key_code: "h",
                        modifiers: ["right_command"],
                    },
                ],
            },
            i: rectangle("first-third"),
            o: rectangle("center-third"),
            p: rectangle("last-third"),
            open_bracket: rectangle("first-two-thirds"),
            close_bracket: rectangle("last-two-thirds"),
        },

        // shortcuts
        c: open("raycast://extensions/raycast/clipboard-history/clipboard-history"),
        g: open("raycast://extensions/raycast/raycast-ai/ai-chat"),
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
            e: open("raycast://ai-commands/improve-english-text"),
            r: open("raycast://ai-commands/improve-russian-text"),
            n: open("raycast://ai-commands/continue-conversation"),
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

const outputFolder = "./dist";
const outputFile = `${outputFolder}/karabiner.json`;

await mkdir(outputFolder, { recursive: true });
await writeFile(outputFile, fileContent, "utf8");

console.log(`Generated Karabiner rules in ${outputFile}`);
