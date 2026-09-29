# Iterating a prompt with measurement

A good prompt is rarely written; it is iterated into. Trying to write the perfect prompt in one shot reliably produces something that feels reasonable but underperforms on inputs you did not think about. This file describes the eval-driven loop that turns a vague intuition ("this should be better") into a measurable claim ("score went from 3.9 to 7.8").

## When to bother

Use the loop for any prompt that will run repeatedly: a system prompt for an agent, a skill description, an automated workflow, a Cron-scheduled task, a customer-facing template. The setup cost (15-30 min for a simple eval harness) is paid back the first time you make a change you thought would help and the score gets worse.

Skip the loop for one-off prompts where the cost of a bad output is low and you are eyeballing the result anyway.

## The loop

1. **Set a goal.** Write one sentence describing what the prompt should accomplish, in plain language. Not "write a meal plan", but "generate a one-day meal plan for an athlete that respects their dietary restrictions, includes calorie and macro totals, and uses budget-friendly foods when budget is specified".

2. **Write a deliberately naive baseline.** Resist the urge to start with a sophisticated prompt. A short, vague first attempt gives you something to measure improvement against. A typical naive prompt scores around 2-4 out of 10 on a thoughtful rubric. That is normal and useful.

3. **Define grading criteria.** List the concrete properties that distinguish a good output from a bad one. For the meal plan example: "Includes daily calorie total. Shows protein, fat, carb amounts. Specifies timing for each meal. Uses only foods allowed by restrictions. Lists portion sizes in grams." Each criterion should be objectively checkable from the output alone.

4. **Pick representative test inputs.** 3 to 5 inputs is enough during iteration. Cover the obvious main case plus the trickier edge cases your prompt is expected to handle. Add more inputs (10-20) only for a final pre-commit validation pass.

5. **Run, grade, score.** Run the prompt against each test input. Grade each output against the criteria. A model-graded score is fine and is usually harsher than a human one (which is what you want). Capture the total score as a baseline.

6. **Apply ONE change.** Pick one technique from `patterns.md` or the SKILL.md core principles. Apply only that change. The discipline of changing one thing at a time is what makes the loop informative; bundle two changes together and you cannot attribute the score delta to either of them.

7. **Re-grade.** Run the same inputs against the new prompt, score again. If the score went up, keep the change and go back to step 6 with a different technique. If it went down, revert and try a different technique.

8. **Stop when.** You have hit a target score, or three iterations in a row produce no improvement, or the inputs you are still failing on are not worth solving for.

## Typical score-delta order

Across many evals, these tend to give the biggest score jumps, roughly in this order, when they are missing from a prompt:

1. **First-line action verb** (replace question with command). Often the single biggest jump for a vague initial prompt.
2. **Output Guidelines** (explicit list of required elements). Doubles the score of a half-thought-out prompt by closing the "what should be in here" gap.
3. **Few-shot examples** for the corner cases that keep failing. The single best lever once Output Guidelines are already in place.
4. **Process Steps** for tasks where the model rushes to an answer and skips angles.
5. **Tightening XML tag names** from generic to descriptive.

The order is a rough heuristic, not a sequence to follow blindly. Look at *what your eval is actually failing on* and pick the technique that addresses that failure mode.

## Mining good outputs

Once a few iterations have produced high-scoring outputs, treat them as raw material. The best of them are exactly what "good" looks like for your task. Lift one or two into the prompt itself as few-shot examples (see `patterns.md` Few-Shot section). Now the prompt teaches by example, not just by description, and future runs reinforce the pattern.

## Anti-patterns

- **Eyeballing.** "This new version *feels* better" is not a measurement. The whole loop exists because intuition about prompt quality is notoriously bad, even among people who write prompts for a living.
- **Bundling changes.** "I will add Output Guidelines AND few-shot examples AND tighten the XML tags, then re-run." You will learn nothing about which of the three mattered. If two of them help and one hurts, you cannot tell.
- **Polishing the wrong end.** If the eval fails because the model is hallucinating facts, no amount of formatting tweaks will fix it. Read the failures, identify the failure mode, then pick the technique that addresses that specific mode.
- **Overfitting to 3 inputs.** If you tune the prompt aggressively against only your hand-picked dev set, it will probably do worse on inputs you have not seen. Run a final pass with 10-20 fresh inputs before declaring success.
- **Skipping the naive baseline.** Starting with an already-decent prompt makes it look like your engineering had no effect. The baseline scoring 3 out of 10 is part of the proof that the loop is working.

## Lightweight harness without dedicated infra

You do not need a dedicated evaluator class. A minimal manual loop is enough:

1. Five test inputs in a markdown file.
2. The current prompt in another markdown file.
3. Run the prompt against each input by hand (or in a small script) and capture the outputs.
4. Open the outputs and the criteria side by side, score each criterion 0/1, sum the scores.

For higher-volume work, automate the grading: send each (criteria, output) pair to the model with a grading prompt asking for a numeric score and a short justification. Capture the numbers, average across inputs.
