package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"os"
	"path/filepath"
	"testing"
)

var update = flag.Bool("update", false, "regenerate the golden file")

const goldenPath = "testdata/karabiner.golden.json"

func TestBuildConfigMatchesGolden(t *testing.T) {
	got, err := json.MarshalIndent(buildConfig("ansi"), "", "  ")
	if err != nil {
		t.Fatalf("marshal config: %v", err)
	}

	if *update {
		if err := os.MkdirAll(filepath.Dir(goldenPath), 0o755); err != nil {
			t.Fatalf("create testdata dir: %v", err)
		}
		if err := os.WriteFile(goldenPath, got, 0o644); err != nil {
			t.Fatalf("write golden: %v", err)
		}
	}

	want, err := os.ReadFile(goldenPath)
	if err != nil {
		t.Fatalf("read golden (run `go test -update` to create it): %v", err)
	}
	if !bytes.Equal(got, want) {
		t.Errorf("buildConfig output does not match %s; run `go test -update` after verifying the diff", goldenPath)
	}
}

func TestRunWritesGoldenToOutput(t *testing.T) {
	want, err := os.ReadFile(goldenPath)
	if err != nil {
		t.Fatalf("read golden: %v", err)
	}

	wd, err := os.Getwd()
	if err != nil {
		t.Fatalf("getwd: %v", err)
	}
	t.Cleanup(func() {
		if err := os.Chdir(wd); err != nil {
			t.Errorf("restore cwd: %v", err)
		}
	})
	if err := os.Chdir(t.TempDir()); err != nil {
		t.Fatalf("chdir: %v", err)
	}

	if err := run("ansi"); err != nil {
		t.Fatalf("run: %v", err)
	}

	got, err := os.ReadFile(filepath.Join("output", "karabiner.json"))
	if err != nil {
		t.Fatalf("read generated config: %v", err)
	}
	if !bytes.Equal(got, want) {
		t.Errorf("run() wrote output that does not match %s", goldenPath)
	}
}

func TestKeyboardTypeFor(t *testing.T) {
	tests := []struct {
		host string
		want string
	}{
		{host: "Pavels-MacBook-Air", want: "iso"},
		{host: "Pavels-MacBook-Pro-2021", want: "ansi"},
		{host: "some-other-mac", want: "ansi"},
	}
	for _, tt := range tests {
		t.Run(tt.host, func(t *testing.T) {
			if got := keyboardTypeFor(tt.host); got != tt.want {
				t.Errorf("keyboardTypeFor(%q) = %q, want %q", tt.host, got, tt.want)
			}
		})
	}
}

func TestBuildConfigCarriesKeyboardType(t *testing.T) {
	got := buildConfig("iso").Profiles[0].VirtualHIDKeyboard.KeyboardTypeV2
	if got != "iso" {
		t.Errorf("keyboard type = %q, want iso", got)
	}
}
