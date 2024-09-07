import { KarabinerRules } from "../types.js";
import { HyperLayerCondition } from "../utils.js";

export const navigationKeys: KarabinerRules[] = [
    {
        description: "Navigation keys",
        manipulators: [
            {
                type: "basic",
                description: "move left",
                from: {
                    key_code: "h",
                },
                to: [
                    {
                        key_code: "left_arrow",
                    },
                ],
                conditions: [HyperLayerCondition],
            },
            {
                type: "basic",
                description: "select left",
                from: {
                    key_code: "h",
                    modifiers: {
                        mandatory: ["command"],
                    },
                },
                to: [
                    {
                        key_code: "left_arrow",
                        modifiers: ["left_shift"],
                    },
                ],
                conditions: [HyperLayerCondition],
            },
            {
                type: "basic",
                description: "select word left",
                from: {
                    key_code: "h",
                    modifiers: {
                        mandatory: ["command", "shift"],
                    },
                },
                to: [
                    {
                        key_code: "left_arrow",
                        modifiers: ["left_shift", "left_option"],
                    },
                ],
                conditions: [HyperLayerCondition],
            },
            {
                type: "basic",
                from: {
                    key_code: "j",
                },
                to: [
                    {
                        key_code: "down_arrow",
                    },
                ],
                conditions: [HyperLayerCondition],
            },
            {
                type: "basic",
                from: {
                    key_code: "j",
                    modifiers: {
                        mandatory: ["command"],
                    },
                },
                to: [
                    {
                        key_code: "down_arrow",
                        modifiers: ["left_shift"],
                    },
                ],
                conditions: [HyperLayerCondition],
            },
            {
                type: "basic",
                from: {
                    key_code: "j",
                    modifiers: {
                        mandatory: ["command", "shift"],
                    },
                },
                to: [
                    {
                        key_code: "down_arrow",
                        modifiers: ["left_shift"],
                    },
                    {
                        key_code: "down_arrow",
                        modifiers: ["left_shift"],
                    },
                    {
                        key_code: "down_arrow",
                        modifiers: ["left_shift"],
                    },
                ],
                conditions: [HyperLayerCondition],
            },
            {
                type: "basic",
                from: {
                    key_code: "k",
                },
                to: [
                    {
                        key_code: "up_arrow",
                    },
                ],
                conditions: [HyperLayerCondition],
            },
            {
                type: "basic",
                from: {
                    key_code: "k",
                    modifiers: {
                        mandatory: ["command"],
                    },
                },
                to: [
                    {
                        key_code: "up_arrow",
                        modifiers: ["left_shift"],
                    },
                ],
                conditions: [HyperLayerCondition],
            },
            {
                type: "basic",
                from: {
                    key_code: "k",
                    modifiers: {
                        mandatory: ["command", "shift"],
                    },
                },
                to: [
                    {
                        key_code: "up_arrow",
                        modifiers: ["left_shift"],
                    },
                    {
                        key_code: "up_arrow",
                        modifiers: ["left_shift"],
                    },
                    {
                        key_code: "up_arrow",
                        modifiers: ["left_shift"],
                    },
                ],
                conditions: [HyperLayerCondition],
            },
            {
                type: "basic",
                from: {
                    key_code: "l",
                },
                to: [
                    {
                        key_code: "right_arrow",
                    },
                ],
                conditions: [HyperLayerCondition],
            },
            {
                type: "basic",
                description: "select left",
                from: {
                    key_code: "l",
                    modifiers: {
                        mandatory: ["command"],
                    },
                },
                to: [
                    {
                        key_code: "right_arrow",
                        modifiers: ["left_shift"],
                    },
                ],
                conditions: [HyperLayerCondition],
            },
            {
                type: "basic",
                description: "select word left",
                from: {
                    key_code: "l",
                    modifiers: {
                        mandatory: ["command", "shift"],
                    },
                },
                to: [
                    {
                        key_code: "right_arrow",
                        modifiers: ["left_shift", "left_option"],
                    },
                ],
                conditions: [HyperLayerCondition],
            },
        ],
    },
];
