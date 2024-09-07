import { KarabinerRules } from "../types.js";
import { HyperLayerCondition } from "../utils.js";

export const deletionKeys: KarabinerRules[] = [
    {
        description: "Deletion keys",
        manipulators: [
            {
                type: "basic",
                description: "delete a word behind",
                from: {
                    key_code: "n",
                },
                to: [
                    {
                        key_code: "delete_or_backspace",
                        modifiers: ["left_option"],
                    },
                ],
                conditions: [HyperLayerCondition],
            },
            {
                type: "basic",
                description: "delete a selection line behind",
                from: {
                    key_code: "n",
                    modifiers: {
                        mandatory: ["command"],
                    },
                },
                to: [
                    {
                        key_code: "left_arrow",
                        modifiers: ["left_shift", "left_command"],
                    },
                    {
                        key_code: "delete_or_backspace",
                    },
                ],
                conditions: [HyperLayerCondition],
            },
            {
                type: "basic",
                description: "delete a full line behind",
                from: {
                    key_code: "n",
                    modifiers: {
                        mandatory: ["option"],
                    },
                },
                to: [
                    {
                        key_code: "delete_or_backspace",
                        modifiers: ["left_command"],
                    },
                ],
                conditions: [HyperLayerCondition],
            },
            {
                type: "basic",
                description: "delete a char ahead",
                from: {
                    key_code: "period",
                },
                to: [
                    {
                        key_code: "delete_forward",
                        modifiers: ["left_option"],
                    },
                ],
                conditions: [HyperLayerCondition],
            },
            {
                type: "basic",
                description: "delete a selection line ahead",
                from: {
                    key_code: "period",
                    modifiers: {
                        mandatory: ["command"],
                    },
                },
                to: [
                    {
                        key_code: "right_arrow",
                        modifiers: ["left_shift", "left_command"],
                    },
                    {
                        key_code: "delete_forward",
                    },
                ],
                conditions: [HyperLayerCondition],
            },
        ],
    },
];
