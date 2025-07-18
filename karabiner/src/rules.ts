import { mkdir, writeFile } from "node:fs/promises";
import type { KarabinerRules, Manipulator } from "./types.js";
import {
  createTapHoldAction,
  createHyperSubLayers,
  createSubLayer,
  delegate,
  executeCommand,
  keyCode,
  open,
  app,
} from "./utils.js";
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
  {
    description: "Hyper Key (⌃⌥⇧⌘)",
    manipulators: [hyperManipulator],
  },
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
    b: app("Arc"),
    z: app("Zed"),
    l: app("Logseq"),
    m: app("Telegram"),
    h: app("Bruno"),
  }),
  ...createHyperSubLayers({
    // search via
    o: {
      g: open("raycast://extensions/raycast/github/search-repositories"),
      a: open("raycast://extensions/the-browser-company/arc/search-history"),
      k: open("raycast://extensions/the-browser-company/arc/search"),
    },

    // w = "Window" via rectangle.app
    w: {
      left_arrow: keyCode("left_arrow", { hyper: true }),
      right_arrow: keyCode("right_arrow", { hyper: true }),
      down_arrow: keyCode("down_arrow", { hyper: true }),
      up_arrow: keyCode("up_arrow", { hyper: true }),
      return_or_enter: keyCode("return_or_enter", { hyper: true }),
      c: keyCode("c", { hyper: true }),
      // Window: Hide
      h: keyCode("w", { modifiers: ["right_command"] }),
      i: keyCode("i", { hyper: true }),
      o: keyCode("o", { hyper: true }),
      p: keyCode("p", { hyper: true }),
      quote: keyCode("quote", { hyper: true }),
      semicolon: keyCode("semicolon", { hyper: true }),
      l: keyCode("l", { hyper: true }),
      k: keyCode("k", { hyper: true }),
      j: keyCode("j", { hyper: true }),
      open_bracket: keyCode("open_bracket", { hyper: true }),
      close_bracket: keyCode("close_bracket", { hyper: true }),
      r: keyCode("r", { hyper: true }),
    },

    // shortcuts
    c: delegate(
      new URL(
        "raycast://extensions/raycast/clipboard-history/clipboard-history",
      ),
    ),
    g: delegate(new URL("raycast://extensions/raycast/raycast-ai/ai-chat")),
    s: {
      a: keyCode("s", { hyper: true }),
      t: keyCode("t", { hyper: true }),
      m: keyCode("m", { hyper: true }),
    },
    a: {
      e: keyCode("1", { hyper: true }),
      r: keyCode("2", { hyper: true }),
      n: keyCode("3", { hyper: true }),
    },
    m: {
      1: createTapHoldAction(
        executeCommand("pk-workspace/memcell/get-mem-cell", {
          cellName: "mem-cell-1",
        }),
        executeCommand("pk-workspace/memcell/save-mem-cell", {
          cellName: "mem-cell-1",
        }),
      ),
      2: createTapHoldAction(
        executeCommand("pk-workspace/memcell/get-mem-cell", {
          cellName: "mem-cell-2",
        }),
        executeCommand("pk-workspace/memcell/save-mem-cell", {
          cellName: "mem-cell-2",
        }),
      ),
      3: createTapHoldAction(
        executeCommand("pk-workspace/memcell/get-mem-cell", {
          cellName: "mem-cell-3",
        }),
        executeCommand("pk-workspace/memcell/save-mem-cell", {
          cellName: "mem-cell-3",
        }),
      ),
      p: createTapHoldAction(
        executeCommand("pk-workspace/memcell/get-mem-cell", {
          cellName: "mock-pass",
        }),
        executeCommand("pk-workspace/memcell/save-mem-cell", {
          cellName: "mock-pass",
        }),
      ),
    },
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
