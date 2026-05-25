import type { From, KarabinerRules, To } from "../types.js";

type Options = {
    isLaptop: boolean;
};

const DefaultOptions: Options = {
    isLaptop: true,
};

const EN_SOURCE_ID = "me.tonsky.keyboardlayout.universal.english-universal";
const RU_SOURCE_ID = "me.tonsky.keyboardlayout.universal.russian-universal";

export const languageSwitch = ({ isLaptop }: Options = DefaultOptions): KarabinerRules[] => {
    const from: From = isLaptop ? { apple_vendor_top_case_key_code: "keyboard_fn" } : { key_code: "left_control" };
    const to: To[] = isLaptop ? [{ key_code: "vk_none" }] : [{ key_code: "left_control" }];

    return [
        {
            description: "Switch to English or Russian",
            manipulators: [
                {
                    type: "basic",
                    from,
                    conditions: [
                        {
                            input_sources: [
                                {
                                    input_source_id: EN_SOURCE_ID,
                                },
                            ],
                            type: "input_source_if",
                        },
                    ],
                    to_if_alone: [
                        {
                            select_input_source: {
                                input_source_id: RU_SOURCE_ID,
                            },
                        },
                    ],
                    to,
                },
                {
                    type: "basic",
                    from,
                    conditions: [
                        {
                            input_sources: [
                                {
                                    input_source_id: RU_SOURCE_ID,
                                },
                            ],
                            type: "input_source_if",
                        },
                    ],
                    to_if_alone: [
                        {
                            select_input_source: {
                                input_source_id: EN_SOURCE_ID,
                            },
                        },
                    ],
                    to,
                },
            ],
        },
    ];
};
