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
