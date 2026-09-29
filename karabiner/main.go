package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// karabiner asks which keyboard type to emulate whenever the profile has none,
// so every rebuild without it brought the question back
var keyboardTypeByHost = map[string]string{
	"Pavels-MacBook-Air": "iso",
}

func keyboardTypeFor(host string) string {
	if kt, ok := keyboardTypeByHost[host]; ok {
		return kt
	}
	return "ansi"
}

func localHostName() (string, error) {
	out, err := exec.Command("scutil", "--get", "LocalHostName").Output()
	if err != nil {
		return "", fmt.Errorf("read LocalHostName: %w", err)
	}
	return strings.TrimSpace(string(out)), nil
}

func buildConfig(keyboardType string) config {
	return config{
		Global: global{ShowInMenuBar: false},
		Profiles: []profile{
			{
				Name:               "Default",
				Selected:           true,
				VirtualHIDKeyboard: virtualHIDKeyboard{KeyboardTypeV2: keyboardType},
				ComplexModifications: complexModifications{
					Rules: []rule{
						doubleCommandQ(),
						languageSwitch(),
						hyperKey(),
						f5ToF13(),
						f6ToF18(),
						escapeSleepFix(),
						mediaSubLayer(),
					},
				},
			},
		},
	}
}

func run(keyboardType string) error {
	data, err := json.MarshalIndent(buildConfig(keyboardType), "", "  ")
	if err != nil {
		return fmt.Errorf("marshal config: %w", err)
	}
	if err := os.MkdirAll("output", 0o755); err != nil {
		return fmt.Errorf("create output dir: %w", err)
	}
	out := filepath.Join("output", "karabiner.json")
	if err := os.WriteFile(out, data, 0o644); err != nil {
		return fmt.Errorf("write %s: %w", out, err)
	}
	fmt.Printf("Generated Karabiner rules in %s\n", out)
	return nil
}

func main() {
	host, err := localHostName()
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	if err := run(keyboardTypeFor(host)); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
