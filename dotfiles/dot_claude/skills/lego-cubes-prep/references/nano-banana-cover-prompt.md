# Cover image prompt - Nano Banana Pro + LEGO aesthetic

This reference is loaded only when assembling the Stage 5 cover prompt. It encodes both the LEGO Cubes visual style (which is fixed across episodes) and the Nano Banana Pro / Gemini 3 Pro Image prompting principles (which are model-specific). Both are deliberately separated from the workflow in SKILL.md so the workflow stays compact and the reference can be tuned independently as the model evolves.

## What Pavel uses for image generation

**Nano Banana Pro** is the community nickname for Google DeepMind's Gemini 3 Pro Image model (released November 2025). It is currently Pavel's tool of choice for Lego Cubes covers. The principles below are tuned to that model. If Pavel switches generators, this file is the right place to update.

## Nano Banana Pro - core prompting principles

### Talk like a creative director, not a search engine

The model is tuned for natural prose, not keyword soup. Avoid `dog, park, 4k, realistic, masterpiece, trending on artstation` style listings. Write full sentences with descriptive adjectives. The model's "Thinking" pre-pass reasons through prose far better than tag dumps.

### The 5-element framework (official Google guidance)

Every prompt should explicitly include all five:

1. **Subject** - be specific. Not "a robot" but "a stoic robot barista with glowing blue optics, made of brushed brass and dark navy enameled panels"
2. **Composition** - how the shot is framed. Examples: extreme close-up, wide shot, low angle, three-quarter elevated, top-down isometric, portrait
3. **Action** - what is happening. Even static subjects should have a verb (posing for a magazine cover, holding a cracked mask, mid-stride on a runway)
4. **Location** - where the scene takes place. Concrete and detailed
5. **Style** - the overall aesthetic (in our case, always LEGO brick diorama, see below)

### Refinement layers (add after the 5 elements)

- **Camera/Lighting** - "Golden hour backlighting creating long shadows", "cinematic color grading with muted teal tones", "key spotlight from upper-left, cold rim light from upper-right"
- **Aspect ratio** - state explicitly: "16:9 widescreen", "1:1 square poster", "9:16 vertical"
- **Resolution** - 1K, 2K, 4K supported. Pavel always wants 4K.
- **Text rendering** - if the image contains any readable text (signs, magazine titles, name tags), specify it word-for-word with font style + color + position. Example: `the headline URBAN EXPLORER rendered in bold, white, sans-serif font at the top`. Vague "add a sign" instructions produce gibberish text.
- **Reference images** (if Pavel passes any) - use the formula `[References] + [Relationship instruction] + [New scenario]`. Up to 14 reference images are accepted. Define the role of each: "Use Image A for the character's pose, Image B for the art style".

### What Nano Banana Pro is bad at

Acknowledge these limits in the prompt design - do not ask for things the model fumbles:

- Very small text and ultra-fine details
- Strict character consistency across multiple regenerations (drifts noticeably)
- Complex blending and seamless edits
- Factual accuracy in data-driven visuals (use Search grounding for diagrams if needed)

## The Lego Cubes house style

Every Lego Cubes cover is a LEGO brick diorama. This is not negotiable - it is Pavel's brand. The variables are camera, subject, color palette, props, lighting, and Easter eggs. Everything else stays fixed.

### Style anchor (always include verbatim or close to it)

> A highly detailed LEGO brick diorama, [camera angle here], with tilt-shift miniature photography effect. [...] Style: official LEGO set photography with visible studs on every single surface. Glossy plastic material with realistic light reflections and subtle subsurface scattering. Dense with hundreds of small details - the scene feels like a premium LEGO Creator Expert set with 3000-5000+ pieces. 16:9 aspect ratio, 4K resolution.

### Camera angles that work

- **Top-down isometric** - good for multi-zone dioramas (lunar base, command centers, building floor plans)
- **Three-quarter elevated** - good for character-focused scenes (fashion editorial, runway, single room)
- **Slightly low angle** - good when the central figure should feel imposing (Sith lord, hero pose)

### Color palette by LEGO brick names

Use real LEGO color terminology - the model recognizes these and renders them more accurately than generic descriptions:

- Greys: light bluish grey, dark bluish grey, light grey, dark grey, pearl light grey, sand blue
- Whites and metallics: white, pearl white, pearl gold, metallic silver, chrome silver
- Reds and warm: dark red, bright red, coral, orange, dark orange, tan, dark tan
- Blues: bright blue, dark blue, medium azure, sand blue, transparent light blue
- Greens: lime green, bright green, dark green, olive green, sand green
- Transparent pieces: transparent clear, transparent light blue, transparent neon orange, transparent neon green, transparent neon purple, transparent red, transparent cyan, transparent magenta

For glitch effects, transparent neon cyan and magenta together read most clearly as "digital corruption". For magical/holographic effects, transparent neon green or transparent light blue read as energy.

### Required structural elements

- **Visible studs on every single surface** - this is the defining LEGO look, mention it in the closing style line
- **Glossy plastic material with light reflections and subtle subsurface scattering** - keeps the plastic feel
- **Tilt-shift miniature photography effect** - makes the diorama read as a small physical object, not a CG environment
- **Hundreds of small details** - implies density, the model fills in props
- **Premium LEGO Creator Expert collaboration set, 3000-5000+ pieces** - this anchors the perceived quality level

### Featured minifigures vs no minifigures

Default rule: `No minifigures anywhere, only traces of human presence` (helmet on the floor, footprints, empty spacesuits, abandoned chairs). This was used for the lunar base (episode 028) and reads cleanly.

Exception: when the title puts a specific iconic character at the center (Darth Maul, Batman, etc.), use that character as a featured LEGO minifigure - the only one in the scene. Specify: `iconic LEGO Star Wars minifigure of Darth Maul with the signature red-and-black tribal tattoo print and golden eyes`. The model recognizes named LEGO minifigures and renders them faithfully.

### Easter eggs

Pavel likes 2-3 subtle nods to the other Content items, tucked into corners or background:
- A tiny labeled folder, briefcase, or file with a name relevant to the content (e.g. `SEPARATE WAYS` for an RE4 reference)
- A magazine cover or poster on the wall
- A silhouette behind a column suggesting another character
- A small phone or screen showing thumbnails of related works

Easter eggs should be discoverable on second look, not dominate the composition. Two or three is the sweet spot - more than five and the scene feels cluttered.

## Composition decision tree

Before writing the prompt, choose the composition based on the title:

**Use single coherent scene when:**
- Title centers on a character or single concept (e.g. "Дьявол носит артефакт повелителя теней", "Оруженосец из черепашьей гавани")
- The metaphor is one location or one figure
- You want a portrait or character-driven cover

**Use multi-zone diorama (4 sectors) when:**
- Title implies survival/anthology/multiple events ("after surviving four disasters")
- Episode covers wildly different domains and you want to show breadth
- The poetic structure is enumerative

Default to single-scene unless Pavel says otherwise. The lunar base (028) was multi-zone; 026, 027, 029 are all single-scene.

## Past episodes - style calibration

These are the canonical recent covers - reference them when reasoning about a new prompt:

- **026 "Снежная кузница параллельных сеансов"** - snowy LEGO forge with parallel workshops, work + Continuum parallel execution, winter palette
- **027 "Оруженосец из черепашьей гавани"** - LEGO squire/armorer figure in turtle harbor setting, Tuclaw assistant + Turtle Ecosystem, warm marine palette
- **028 lunar base** - top-down isometric 4-sector lunar base diorama, four disasters as four corrupted sectors, sunrise lighting
- **029 "Дьявол носит артефакт повелителя теней"** - three-quarter elevated, Darth Maul minifigure as fashion model in editorial studio, holding a glitched mask, fashion + Sith + Glitch project triple meaning

## Prompt assembly template

Use this skeleton when writing a new cover prompt. Fill in the bracketed sections:

```
A highly detailed LEGO brick diorama of [SUBJECT + ACTION], viewed from a [CAMERA ANGLE] with tilt-shift miniature photography effect.

The setting is [LOCATION DESCRIPTION] built from [3-5 LEGO color names] LEGO tiles. [2-3 sentences of setting detail - architecture, layout, defining features].

At the center [CENTRAL FIGURE OR OBJECT in detail - LEGO color palette, pose, costume, key prop in hand]. [If glitch/magical effect: describe the transparent neon pieces and how they manifest].

Surrounding details: [3-5 sentences of props, secondary objects, named text on signs/magazines, atmospheric items]. [Easter eggs woven in - 2-3 small references to other Content items, described as physical objects in the scene with named labels].

Atmosphere and lighting: [primary light source and direction], [secondary/contrasting light], [color temperature contrast between sections]. [Particle effects if relevant - "transparent cyan 1x1 round LEGO plates drifting through the air around the mask"]. [Background sky/wall description].

Style: official LEGO set photography with visible studs on every single surface. Glossy plastic material with realistic light reflections and subtle subsurface scattering. Dense with hundreds of small details - the scene feels like a premium LEGO Creator Expert collaboration set with [3000-5000]+ pieces. [No minifigures anywhere, only traces of human presence | No minifigures except the featured central minifigure of <character>]. 16:9 aspect ratio, 4K resolution.
```

## Output format in chat

After writing the prompt:

1. Output the full prompt as a single fenced code block (so Pavel can one-click copy)
2. Below the code block, write a 3-5 bullet `## Что в нём заложено` summary explaining:
   - Central figure/object and which title element it embodies
   - Color palette logic
   - Which Easter eggs went in and which Content items they reference
   - Lighting choice and why
   - Any composition decisions worth flagging (zones vs single scene, minifigure vs none)

This explanation is what Pavel reads to decide whether to tweak. Keep it tight - bullet points, no walls of text.

## Iteration

If Pavel asks for a change:
- **New central figure/concept** - rewrite the central paragraph and Easter eggs, keep style anchor + lighting boilerplate stable
- **Different color mood** - swap the palette names, leave structure intact
- **More/fewer Easter eggs** - just adjust the surrounding details paragraph
- **Switch single-scene <-> multi-zone** - this is a bigger rewrite, treat it as a fresh prompt

The style anchor (visible studs, tilt-shift, glossy plastic, Creator Expert feel, 16:9 4K) should never be cut.
