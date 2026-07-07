import type { Conditions, From, KarabinerRules, Manipulator, To } from "../types.js";

const EN_SOURCE_ID = "me.tonsky.keyboardlayout.universal.english-universal";
const RU_SOURCE_ID = "me.tonsky.keyboardlayout.universal.russian-universal";

const externalKeyboard: Conditions = {
    type: "device_unless",
    identifiers: { is_built_in_keyboard: true },
};

type Variant = {
    from: From;
    to: To[];
    device?: Conditions;
};

const variants: Variant[] = [
    {
        from: { apple_vendor_top_case_key_code: "keyboard_fn" },
        to: [{ key_code: "vk_none" }],
    },
    {
        from: { key_code: "left_control" },
        to: [{ key_code: "left_control" }],
        device: externalKeyboard,
    },
];

const toggle = ({ from, to, device }: Variant, whenSource: string, switchTo: string): Manipulator => ({
    type: "basic",
    from,
    conditions: [
        {
            type: "input_source_if",
            input_sources: [{ input_source_id: whenSource }],
        },
        ...(device ? [device] : []),
    ],
    to_if_alone: [{ select_input_source: { input_source_id: switchTo } }],
    to,
});

export const languageSwitch = (): KarabinerRules[] => [
    {
        description: "Switch to English or Russian",
        manipulators: variants.flatMap((variant) => [
            toggle(variant, EN_SOURCE_ID, RU_SOURCE_ID),
            toggle(variant, RU_SOURCE_ID, EN_SOURCE_ID),
        ]),
    },
];
