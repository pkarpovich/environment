import { KarabinerRules } from "../types.js";

export const languageSwitch: KarabinerRules[] = [
    {
        description: "Switch to English or Russian",
        manipulators: [
            {
                type: "basic",
                from: {
                    key_code: "right_command",
                },
                conditions: [
                    {
                        input_sources: [
                            {
                                language: "en",
                            },
                        ],
                        type: "input_source_if",
                    },
                ],
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
            {
                type: "basic",
                from: {
                    key_code: "right_command",
                },
                conditions: [
                    {
                        input_sources: [
                            {
                                language: "ru",
                            },
                        ],
                        type: "input_source_if",
                    },
                ],
                to_if_alone: [
                    {
                        select_input_source: {
                            language: "en",
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
