---
description: plan contract - whether every boundary the plan crosses is written down as a request, a response and a failure, with evidence for where each shape came from
---
## Lens: plan-contract

A plan is a specification, and a specification that stops at the edge of the repository is unfinished.
Wherever the work crosses a boundary - an HTTP endpoint, a SOAP action, a device protocol, a CLI a task
shells out to and parses, a library whose response shape the code branches on - the plan carries the
contract, so that no session ever has to go and find out.

The failure this exists to prevent is deferred discovery. When the shape is absent, one of two things
happens and both are expensive: a fresh session invents a shape and builds against it, or the plan
grows a task whose job is to go and look - at which point the plan has handed the executor its author's
homework, and every task downstream waits on data that may never arrive.

For each boundary, four things:

- **the request** - method, path or action, the headers that matter, the body with real values, how it
  is authorised
- **the response** - the statuses that actually occur, and the body with values that were observed
  rather than composed. `<ip>`, `foo`, `example.com` and suspiciously round numbers are the tell
- **the failure** - what a rejection looks like on the wire. Not "returns an error" but the status,
  the body and the message, especially when the code branches on any of them
- **the provenance** - where the shape came from. A fixture committed in the repository, a vendor
  document with a URL, or an existing call site the plan names. **A shape with no provenance cannot be
  told apart from an invented one**, and the strongest form is a fixture captured off the live system
  before the plan was written

Look for:

- a boundary named and not specified: "call the API and parse the response", "read the device
  description", "send the command"
- a shape given in prose with no example, so two readings of "returns a list of rooms" produce two
  different parsers
- a shape with no provenance at all, or one whose values read as composed rather than captured
- **a task whose work is to discover the shape.** This is the loudest signal the lens has: the plan is
  saying out loud that its own contract is missing, and it is usually the task that also cannot run
  where the plan runs
- a fixture the plan relies on that is not in the repository, or one a task of this plan creates rather
  than the author having captured it already
- a value the plan promises to record later, or a rule it says it will relax once something is observed
- error handling keyed on a code, a field or a message the plan never shows
- a field the code depends on whose behaviour is unstated: whether it can be absent, what the empty
  case looks like, whether a value sent comes back unchanged. A comparison the plan performs on a value
  it never saw round-trip is a guess with a test attached
- two places in the plan describing the same boundary differently

**Check the evidence, do not take the citation.** When the plan names a fixture, open it and confirm it
holds what the plan says it holds. When it cites a document, that citation is only as good as its being
specific - a link to a product's home page is not provenance. If you cannot open what is cited, report
that as its own finding rather than passing the citation through.

Not a finding:

- a boundary inside this repository. Its shape is in the code, and a cold session can read it
- a vendor document cited specifically. It is provenance in its own right, not a weaker fixture
- a library whose result the code hands onward without inspecting. No branch depends on the shape, so
  no contract is owed
- a shape given as types or a field list rather than a captured body, where the project's own plans do
  it that way and the values are not what the work turns on
- an internal helper's signature. This lens watches the edges of the system, not its seams
