import { mkdir, writeFile } from "node:fs/promises";
import type { KarabinerRules, Manipulator } from "./types.js";
import { createSubLayer, keyCode, app } from "./utils.js";
import { doubleCommandQ } from "./customRules/doubleCommandQ.js";
import { languageSwitch } from "./customRules/languageSwitch.js";

const hyperManipulator: Manipulator = {
  description: "Caps Lock -> Hyper Key",
  from: {
    key_code: "caps_lock",
    modifiers: {
      optional: ["any"],
    },
  },
  to: [
    {
      set_variable: {
        name: "hyper",
        value: 1,
      },
    },
    {
      key_code: "right_shift",
      modifiers: ["right_control", "left_option", "left_command"],
      lazy: true,
    },
  ],
  to_after_key_up: [
    {
      set_variable: {
        name: "hyper",
        value: 0,
      },
    },
  ],
  type: "basic",
};

type RulesOptions = {
  isLaptop: boolean;
};

const rules = ({ isLaptop }: RulesOptions) => [
  // Temporarily disabled — re-enable to restore Hyper.
  // {
  //   description: "Hyper Key (⌃⌥⇧⌘)",
  //   manipulators: [hyperManipulator],
  // },
  ...doubleCommandQ,
  ...languageSwitch({ isLaptop }),
  // ...navigationKeys,
  // ...deletionKeys,
  // https://github.com/pqrs-org/Karabiner-Elements/issues/2880#issuecomment-1774847928
  {
    description: "Temporary Fix for sleep issue",
    manipulators: [
      {
        type: "basic",
        from: {
          key_code: "escape",
        },
        to_if_alone: [
          {
            key_code: "escape",
          },
        ],
      },
    ],
  },
  createSubLayer("right_option", "Media Commands Sublayer + Apps", {
    s: keyCode("play_or_pause"),
    d: keyCode("fastforward"),
    a: keyCode("rewind"),
    t: app("WezTerm"),
    g: app("GoLand"),
    w: app("WebStorm"),
    b: app("Dia"),
    z: app("Zed"),
    l: app("Logseq"),
    m: app("Telegram"),
    h: app("Bruno v3 Preview"),
    n: app("Obsidian"),
    f: app("Finder"),
    c: app("Claude"),
    4: app("Sublime Merge"),
  }),
];

const isLaptop = process.argv.includes("--laptop");

const fileContent = JSON.stringify(
  {
    global: {
      show_in_menu_bar: false,
    },
    profiles: [
      {
        name: "Default",
        selected: true,
        complex_modifications: {
          rules: rules({ isLaptop }),
        },
      },
    ],
  },
  null,
  2,
);

const outputFolder = "./dist";
const outputFile = `${outputFolder}/karabiner.json`;

await mkdir(outputFolder, { recursive: true });
await writeFile(outputFile, fileContent, "utf8");

console.log(`Generated Karabiner rules in ${outputFile}`);
