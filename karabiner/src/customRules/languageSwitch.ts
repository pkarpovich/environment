import type { From, KarabinerRules, To } from "../types.js";

type Options = {
    isLaptop: boolean;
};

const DefaultOptions: Options = {
    isLaptop: true,
};

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
                    to,
                },
                {
                    type: "basic",
                    from,
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
                    to,
                },
            ],
        },
    ];
};
