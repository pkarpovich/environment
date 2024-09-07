import type { KarabinerRules } from "../types.js";

export const doubleCommandQ: KarabinerRules[] = [
    {
        description: "Double Command+Q to quit",
        manipulators: [
            {
                conditions: [
                    {
                        name: "command-q",
                        type: "variable_if",
                        value: 1,
                    },
                ],
                from: {
                    key_code: "q",
                    modifiers: {
                        mandatory: ["command"],
                    },
                },
                to: [
                    {
                        key_code: "q",
                        modifiers: ["left_command"],
                    },
                ],
                type: "basic",
            },
            {
                from: {
                    key_code: "q",
                    modifiers: {
                        mandatory: ["command"],
                    },
                },
                to: [
                    {
                        set_variable: {
                            name: "command-q",
                            value: 1,
                        },
                    },
                ],
                to_delayed_action: {
                    to_if_canceled: [
                        {
                            set_variable: {
                                name: "command-q",
                                value: 0,
                            },
                        },
                    ],
                    to_if_invoked: [
                        {
                            set_variable: {
                                name: "command-q",
                                value: 0,
                            },
                        },
                    ],
                },
                type: "basic",
            },
        ],
    },
];
