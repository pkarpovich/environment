package main

import "fmt"

type layerCmd struct {
	to          []to
	description string
}

type layerEntry struct {
	key string
	cmd layerCmd
}

func keyCode(code string) layerCmd {
	return layerCmd{to: []to{{KeyCode: code}}}
}

func app(name string) layerCmd {
	return layerCmd{
		to: []to{{
			ShellCommand: fmt.Sprintf(
				`open -a "%s" && sleep 0.1 && osascript -e 'tell application "System Events" to set frontmost of process "%s" to true'`,
				name, name,
			),
		}},
		description: "Open and focus " + name,
	}
}

func subLayer(modifier, description string, entries []layerEntry) rule {
	manipulators := make([]manipulator, len(entries))
	for i, e := range entries {
		manipulators[i] = manipulator{
			Type:        "basic",
			Description: e.cmd.description,
			From: from{
				KeyCode:   e.key,
				Modifiers: &modifiers{Mandatory: []string{modifier}},
			},
			To: e.cmd.to,
		}
	}
	return rule{Description: description, Manipulators: manipulators}
}

func intPtr(v int) *int { return &v }

func doubleCommandQ() rule {
	commandQ := from{KeyCode: "q", Modifiers: &modifiers{Mandatory: []string{"command"}}}
	reset := []to{{SetVariable: &setVariable{Name: "command-q", Value: 0}}}
	return rule{
		Description: "Double Command+Q to quit",
		Manipulators: []manipulator{
			{
				Type:       "basic",
				From:       commandQ,
				To:         []to{{KeyCode: "q", Modifiers: []string{"left_command"}}},
				Conditions: []condition{{Type: "variable_if", Name: "command-q", Value: intPtr(1)}},
			},
			{
				Type: "basic",
				From: commandQ,
				To:   []to{{SetVariable: &setVariable{Name: "command-q", Value: 1}}},
				ToDelayedAction: &delayedAction{
					ToIfInvoked:  reset,
					ToIfCanceled: reset,
				},
			},
		},
	}
}

const (
	enSourceID = "me.tonsky.keyboardlayout.universal.english-universal"
	ruSourceID = "me.tonsky.keyboardlayout.universal.russian-universal"
)

type langVariant struct {
	from   from
	to     []to
	device *condition
}

type langDirection struct {
	when     string
	switchTo string
}

func (v langVariant) toggle(dir langDirection) manipulator {
	conditions := []condition{
		{Type: "input_source_if", InputSources: []inputSource{{InputSourceID: dir.when}}},
	}
	if v.device != nil {
		conditions = append(conditions, *v.device)
	}
	return manipulator{
		Type:       "basic",
		From:       v.from,
		Conditions: conditions,
		ToIfAlone:  []to{{SelectInputSource: &inputSource{InputSourceID: dir.switchTo}}},
		To:         v.to,
	}
}

func languageSwitch() rule {
	variants := []langVariant{
		{
			from: from{AppleVendorTopCaseKeyCode: "keyboard_fn"},
			to:   []to{{KeyCode: "vk_none"}},
		},
		{
			from:   from{KeyCode: "left_control"},
			to:     []to{{KeyCode: "left_control"}},
			device: &condition{Type: "device_unless", Identifiers: []identifiers{{IsBuiltInKeyboard: true}}},
		},
	}
	var manipulators []manipulator
	for _, v := range variants {
		manipulators = append(manipulators,
			v.toggle(langDirection{when: enSourceID, switchTo: ruSourceID}),
			v.toggle(langDirection{when: ruSourceID, switchTo: enSourceID}),
		)
	}
	return rule{Description: "Switch to English or Russian", Manipulators: manipulators}
}

func f5ToF13() rule {
	return rule{
		Description: "F5 -> F13",
		Manipulators: []manipulator{
			{
				Type: "basic",
				From: from{KeyCode: "f5", Modifiers: &modifiers{Optional: []string{"any"}}},
				To:   []to{{KeyCode: "f13"}},
			},
		},
	}
}

func escapeSleepFix() rule {
	return rule{
		Description: "Temporary Fix for sleep issue",
		Manipulators: []manipulator{
			{
				Type:      "basic",
				From:      from{KeyCode: "escape"},
				ToIfAlone: []to{{KeyCode: "escape"}},
			},
		},
	}
}

func mediaAppsSubLayer() rule {
	return subLayer("right_option", "Media Commands Sublayer + Apps", []layerEntry{
		{key: "s", cmd: keyCode("play_or_pause")},
		{key: "d", cmd: keyCode("fastforward")},
		{key: "a", cmd: keyCode("rewind")},
		{key: "t", cmd: app("WezTerm")},
		{key: "g", cmd: app("GoLand")},
		{key: "w", cmd: app("WebStorm")},
		{key: "b", cmd: app("Dia")},
		{key: "z", cmd: app("Zed")},
		{key: "l", cmd: app("Logseq")},
		{key: "m", cmd: app("Telegram")},
		{key: "h", cmd: app("Bruno v3 Preview")},
		{key: "n", cmd: app("Obsidian")},
		{key: "f", cmd: app("Finder")},
		{key: "c", cmd: app("Claude")},
		{key: "4", cmd: app("Sublime Merge")},
	})
}
