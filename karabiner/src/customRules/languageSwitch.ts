import { KarabinerRules } from "../types.js";

export const languageSwitch: KarabinerRules[] = [
    {
        description: "Switch to English",
        manipulators: [
            {
                type: "basic",
                from: {
                    key_code: "left_command",
                },
                to_if_alone: [
                    {
                        select_input_source: {
                            language: "en",
                        },
                    },
                ],
                to: [
                    {
                        key_code: "left_command",
                    },
                ],
            },
        ],
    },
    {
        description: "Switch to Russian",
        manipulators: [
            {
                type: "basic",
                from: {
                    key_code: "right_command",
                },
                to_if_alone: [
                    {
                        select_input_source: {
                            language: "ru",
                        },
                    },
                ],
                to: [
                    {
                        key_code: "right_command",
                    },
                ],
            },
        ],
    },
];
