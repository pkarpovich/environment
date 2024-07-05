/**
 * Create a Hyper Key sublayer, where every command is prefixed with a key
 * e.g. Hyper + O ("Open") is the "open applications" layer, I can press
 * e.g. Hyper + O + G ("Google Chrome") to open Chrome
 */
export function createHyperSubLayer(sublayer_key, commands, allSubLayerVariables) {
    const subLayerVariableName = generateSubLayerVariableName(sublayer_key);
    return [
        // When Hyper + sublayer_key is pressed, set the variable to 1; on key_up, set it to 0 again
        {
            description: `Toggle Hyper sublayer ${sublayer_key}`,
            type: "basic",
            from: {
                key_code: sublayer_key,
                modifiers: {
                    mandatory: ["left_command", "left_control", "left_shift", "left_option"],
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
            conditions: allSubLayerVariables
                .filter((subLayerVariable) => subLayerVariable !== subLayerVariableName)
                .map((subLayerVariable) => ({
                type: "variable_if",
                name: subLayerVariable,
                value: 0,
            })),
        },
        // Define the individual commands that are meant to trigger in the sublayer
        ...Object.keys(commands).map((command_key) => ({
            ...commands[command_key],
            type: "basic",
            from: {
                key_code: command_key,
                modifiers: {
                    // Mandatory modifiers are *not* added to the "to" event
                    mandatory: ["any"],
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
        })),
    ];
}
/**
 * Create all hyper sublayers. This needs to be a single function, as well need to
 * have all the hyper variable names in order to filter them and make sure only one
 * activates at a time
 */
export function createHyperSubLayers(subLayers) {
    const allSubLayerVariables = Object.keys(subLayers).map((sublayer_key) => generateSubLayerVariableName(sublayer_key));
    return Object.entries(subLayers).map(([key, value]) => "to" in value
        ? {
            description: `Hyper Key + ${key}`,
            manipulators: [
                {
                    ...value,
                    type: "basic",
                    from: {
                        key_code: key,
                        modifiers: {
                            // Mandatory modifiers are *not* added to the "to" event
                            mandatory: ["left_command", "left_control", "left_shift", "left_option"],
                        },
                    },
                },
            ],
        }
        : {
            description: `Hyper Key sublayer "${key}"`,
            manipulators: createHyperSubLayer(key, value, allSubLayerVariables),
        });
}
/**
 * Create a sublayer
 * @param layer_key
 * @param description
 * @param subLayers
 */
export function createSubLayer(layer_key, description, subLayers) {
    return {
        description: description,
        manipulators: Object.entries(subLayers).map(([key, value]) => ({
            type: "basic",
            from: {
                key_code: key,
                modifiers: {
                    mandatory: [layer_key],
                },
            },
            ...value,
        })),
    };
}
function generateSubLayerVariableName(key) {
    return `hyper_sublayer_${key}`;
}
/**
 * Shortcut for "open" shell command
 */
export function open(what) {
    return {
        to: [
            {
                shell_command: `open ${what}`,
            },
        ],
        description: `Open ${what}`,
    };
}
/**
 * Shortcut for "Open an app" command (of which there are a bunch)
 */
export function app(name) {
    return open(`-a '${name}.app'`);
}
