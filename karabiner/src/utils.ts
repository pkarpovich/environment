import type { To, KeyCode, Manipulator, KarabinerRules, Modifiers, ModifiersKeys, Conditions } from "./types.js";

/**
 * Custom way to describe a command in a layer
 */
export interface LayerCommand {
    to: To[];
    to_if_alone?: To[];
    to_after_key_up?: To[];
    from?: {
        key_code: KeyCode;
        modifiers: {
            optional: ["any"];
        };
    };
    description?: string;
}

type HyperKeySublayer = {
    // The ? is necessary, otherwise we'd have to define something for _every_ key code
    [key_code in KeyCode]?: LayerCommand;
};

type SubLayers = {
    [key_code in KeyCode]?: HyperKeySublayer | LayerCommand;
};

export const HyperLayerCondition: Conditions = {
    type: "variable_if",
    name: "hyper",
    value: 1,
};

/**
 * Create a Hyper Key sublayer, where every command is prefixed with a key
 * e.g. Hyper + O ("Open") is the "open applications" layer, I can press
 * e.g. Hyper + O + G ("Google Chrome") to open Chrome
 */
export function createHyperSubLayer(
    sublayer_key: KeyCode,
    commands: HyperKeySublayer,
    allSubLayerVariables: string[],
): Manipulator[] {
    const subLayerVariableName = generateSubLayerVariableName(sublayer_key);

    return [
        // When Hyper + sublayer_key is pressed, set the variable to 1; on key_up, set it to 0 again
        {
            description: `Toggle Hyper sublayer ${sublayer_key}`,
            type: "basic",
            from: {
                key_code: sublayer_key,
                modifiers: {
                    optional: ["any"],
                },
            },
            to_after_key_up: [
                {
                    set_variable: {
                        name: subLayerVariableName,
                        // The default value of a variable is 0: https://karabiner-elements.pqrs.org/docs/json/complex-modifications-manipulator-definition/conditions/variable/
                        // That means by using 0 and 1 we can filter for "0" in the conditions below and it'll work on startup
                        value: 0,
                    },
                },
            ],
            to: [
                {
                    set_variable: {
                        name: subLayerVariableName,
                        value: 1,
                    },
                },
            ],
            // This enables us to press other sublayer keys in the current sublayer
            // (e.g. Hyper + O > M even though Hyper + M is also a sublayer)
            // basically, only trigger a sublayer if no other sublayer is active
            conditions: [
                ...allSubLayerVariables
                    .filter((subLayerVariable) => subLayerVariable !== subLayerVariableName)
                    .map((subLayerVariable) => ({
                        type: "variable_if" as const,
                        name: subLayerVariable,
                        value: 0,
                    })),
                HyperLayerCondition,
            ],
        },
        // Define the individual commands that are meant to trigger in the sublayer
        ...(Object.keys(commands) as (keyof typeof commands)[]).map(
            (command_key): Manipulator => ({
                ...commands[command_key],
                type: "basic" as const,
                from: {
                    key_code: command_key,
                    modifiers: {
                        optional: ["any"],
                    },
                },
                // Only trigger this command if the variable is 1 (i.e., if Hyper + sublayer is held)
                conditions: [
                    {
                        type: "variable_if",
                        name: subLayerVariableName,
                        value: 1,
                    },
                ],
            }),
        ),
    ];
}

/**
 * Create all hyper sublayers. This needs to be a single function, as well need to
 * have all the hyper variable names in order to filter them and make sure only one
 * activates at a time
 */
export function createHyperSubLayers(subLayers: {
    [key_code in KeyCode]?: HyperKeySublayer | LayerCommand;
}): KarabinerRules[] {
    const allSubLayerVariables = (Object.keys(subLayers) as (keyof typeof subLayers)[]).map((sublayer_key) =>
        generateSubLayerVariableName(sublayer_key),
    );

    return Object.entries(subLayers).map(([key, value]) =>
        "to" in value
            ? {
                  description: `Hyper Key + ${key}`,
                  manipulators: [
                      {
                          ...value,
                          type: "basic" as const,
                          from: {
                              key_code: key as KeyCode,
                              modifiers: {
                                  optional: ["any"],
                              },
                          },
                          conditions: [
                              {
                                  type: "variable_if",
                                  name: "hyper",
                                  value: 1,
                              },
                              ...allSubLayerVariables.map((subLayerVariable) => ({
                                  type: "variable_if" as const,
                                  name: subLayerVariable,
                                  value: 0,
                              })),
                          ],
                      },
                  ],
              }
            : {
                  description: `Hyper Key sublayer "${key}"`,
                  manipulators: createHyperSubLayer(key as KeyCode, value, allSubLayerVariables),
              },
    );
}

function generateSubLayerVariableName(key: KeyCode) {
    return `hyper_sublayer_${key}`;
}

export function createSubLayer(layer_key: string, description: string, subLayers: SubLayers): KarabinerRules {
    return {
        description: description,
        manipulators: Object.entries(subLayers).map(
            ([key, value]) =>
                ({
                    type: "basic",
                    from: {
                        key_code: key as KeyCode,
                        modifiers: {
                            mandatory: [layer_key],
                        },
                    },
                    ...value,
                }) as Manipulator,
        ),
    };
}

/**
 * Shortcut for "open" shell command
 */
export function open(what: string, options = { foreground: true, raw: false }): LayerCommand {
    return {
        to: [openRaw(what, options)],
        description: `Open ${what}`,
    };
}

export function openRaw(what: string, options = { foreground: true, raw: false }): To {
    const command = options.foreground ? `open ${what}` : `open -g ${what}`;

    return {
        shell_command: command,
    };
}

export function delegate(url: URL, options = { foreground: true, raw: false }): LayerCommand {
    return open(url.toString(), options);
}

export function delegateRaw(url: URL, options = { foreground: true, raw: false }): To {
    return openRaw(url.toString(), options);
}

/**
 * Utility function to create a LayerCommand from a tagged template literal
 * where each line is a shell command to be executed.
 */
export function shell(strings: TemplateStringsArray, ...values: any[]): LayerCommand {
    const commands = strings.reduce((acc, str, i) => {
        const value = i < values.length ? values[i] : "";
        const lines = (str + value).split("\n").filter((line) => line.trim() !== "");
        acc.push(...lines);
        return acc;
    }, [] as string[]);

    return {
        to: commands.map((command) => ({
            shell_command: command.trim(),
        })),
        description: commands.join(" && "),
    };
}

/**
 * Shortcut for managing window sizing
 */
export function windowManagement(name: string): LayerCommand {
    return delegate(new URL(`raycast://extensions/raycast/window-management/${name}?launchType=background`));
}

/**
 * Shortcut for "Open an app" command (of which there are a bunch)
 */
export function app(name: string): LayerCommand | To {
    return open(`-a '${name}.app'`);
}

type KeyCodeOptions = {
    hyper?: boolean;
    modifiers?: ModifiersKeys[];
};

export const Hyper: ModifiersKeys[] = ["left_command", "left_option", "left_control", "left_shift"];

export function keyCode(keyCode: KeyCode, { modifiers = [], hyper = false }: KeyCodeOptions = {}): LayerCommand {
    const keyModifiers: ModifiersKeys[] = hyper ? [...Hyper, ...modifiers] : modifiers;

    return {
        to: [
            {
                key_code: keyCode,
                modifiers: keyModifiers,
            },
        ],
    };
}
