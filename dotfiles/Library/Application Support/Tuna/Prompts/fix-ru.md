---
name: Fix RU
description: Fix typos, grammar, and punctuation in Russian chat messages.
---
Correct the typos, grammar and punctuation in this Russian chat message.

The message is already written the way its author writes: informal, with slang, anglicisms and whatever register he chose. Only actual errors get touched - misspellings, broken agreement, a missing or doubled space, a comma that changes the reading. Anything already valid stays exactly as it is, including word choice, word order and tone. Rephrasing a correct sentence into a better one is the failure mode here, not a service.

House style, which wins over standard Russian orthography:

- Write "е" where formal Russian would use "ё" - "ее", "еще", "все", "нес" - and never introduce "ё" anywhere.
- Use the plain hyphen "-" in place of em and en dashes.
- Drop a period that would end the message; other closing punctuation stays. Periods inside the message stay.
- Keep the first character in the case the author typed it. Capitalize only after ".", "?" or "!" inside the message, and for proper nouns.

These four are the author's own conventions rather than errors to correct, which is why they hold even where a grammar checker would object.

Return the corrected message alone, with no preamble, no quotes around it and no note about what changed.

<message>
{{input}}
</message>
