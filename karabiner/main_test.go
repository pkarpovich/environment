package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"flag"
	"io/fs"
	"os"
	"path/filepath"
	"reflect"
	"sort"
	"testing"
)

var update = flag.Bool("update", false, "regenerate the golden file")

const goldenPath = "testdata/karabiner.golden.json"

func TestBuildConfigMatchesGolden(t *testing.T) {
	got, err := json.MarshalIndent(buildConfig(), "", "  ")
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

const tsReferencePath = "testdata/ts-reference.json"

const mediaSubLayerDescription = "Media Commands Sublayer + Apps"

// TestBuildConfigSemanticParityWithTS asserts the Go generator produces output
// behaviorally identical to the legacy TypeScript generator. It compares parsed
// trees (key ordering differs between TS insertion order and Go struct order),
// after neutralizing two representational deltas that the Go port introduces on
// purpose and that Karabiner treats identically:
//
//  1. The Go port emits bare keyCode commands with no "modifiers" (Task 2's
//     explicit choice; TS defaults them to an empty `modifiers: []`).
//  2. The media sublayer manipulators key off distinct letters, so their order
//     is behaviorally irrelevant; TS floats the integer-like key "4" to the
//     front (JS object key iteration), while the Go port keeps source order.
//
// The reference file is not committed, so the test skips when it is absent.
func TestBuildConfigSemanticParityWithTS(t *testing.T) {
	refBytes, err := os.ReadFile(tsReferencePath)
	if errors.Is(err, fs.ErrNotExist) {
		t.Skipf("%s absent; run the TS generator and copy its output here to enable the semantic parity check", tsReferencePath)
	}
	if err != nil {
		t.Fatalf("read TS reference: %v", err)
	}

	goBytes, err := json.MarshalIndent(buildConfig(), "", "  ")
	if err != nil {
		t.Fatalf("marshal config: %v", err)
	}

	goTree := normalizeForParity(t, goBytes)
	refTree := normalizeForParity(t, refBytes)

	if !reflect.DeepEqual(goTree, refTree) {
		t.Errorf("Go output is not behaviorally equal to the TS reference in %s", tsReferencePath)
	}
}

func normalizeForParity(t *testing.T, data []byte) map[string]any {
	t.Helper()
	var tree map[string]any
	if err := json.Unmarshal(data, &tree); err != nil {
		t.Fatalf("unmarshal config: %v", err)
	}
	stripEmptyModifiers(tree)
	sortMediaSubLayer(tree)
	return tree
}

// stripEmptyModifiers deletes every "modifiers" key whose value is an empty
// array. An empty modifiers list is behaviorally identical to an absent one;
// populated modifiers (arrays or the from-side object) are left untouched, so a
// real empty-vs-populated mismatch still fails the comparison.
func stripEmptyModifiers(v any) {
	switch t := v.(type) {
	case map[string]any:
		for k, val := range t {
			if k == "modifiers" {
				if arr, ok := val.([]any); ok && len(arr) == 0 {
					delete(t, k)
					continue
				}
			}
			stripEmptyModifiers(val)
		}
	case []any:
		for _, e := range t {
			stripEmptyModifiers(e)
		}
	}
}

// sortMediaSubLayer orders the media sublayer's manipulators by from.key_code so
// the two generators' differing sequences compare equal. Sorting preserves each
// (key_code -> command) pairing, so a mis-mapped key still fails the comparison;
// only the behaviorally irrelevant sequence is normalized, and only for this one
// rule (rules with overlapping from keys stay order-sensitive).
func sortMediaSubLayer(tree map[string]any) {
	for _, r := range rulesOf(tree) {
		rule, ok := r.(map[string]any)
		if !ok || rule["description"] != mediaSubLayerDescription {
			continue
		}
		manipulators, ok := rule["manipulators"].([]any)
		if !ok {
			continue
		}
		sort.SliceStable(manipulators, func(i, j int) bool {
			return fromKeyCode(manipulators[i]) < fromKeyCode(manipulators[j])
		})
	}
}

func rulesOf(tree map[string]any) []any {
	profiles, ok := tree["profiles"].([]any)
	if !ok || len(profiles) == 0 {
		return nil
	}
	profile, ok := profiles[0].(map[string]any)
	if !ok {
		return nil
	}
	mods, ok := profile["complex_modifications"].(map[string]any)
	if !ok {
		return nil
	}
	rules, _ := mods["rules"].([]any)
	return rules
}

func fromKeyCode(manipulator any) string {
	m, ok := manipulator.(map[string]any)
	if !ok {
		return ""
	}
	from, ok := m["from"].(map[string]any)
	if !ok {
		return ""
	}
	code, _ := from["key_code"].(string)
	return code
}
