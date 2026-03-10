# MCP Tool Integration

Claude has access to external MCP tools.

## Stitch MCP

Configured with:

claude mcp add stitch --transport http https://stitch.googleapis.com/mcp --header "X-Goog-Api-Key: api-key" -s user

Capabilities:

* access Google APIs
* run AI services
* fetch structured data
* integrate external ML services

Claude should use Stitch MCP when:

* external AI services are beneficial
* Google APIs are required
* structured data retrieval is needed

---

## Nano Banana

AI image generation CLI powered by Gemini. Installed at ~/tools/nano-banana-2.
Run via: ~/.bun/bin/bun ~/tools/nano-banana-2/src/cli.ts "prompt" [options]

Role in this project: UI frame generation ONLY.
Do NOT use for visual validation or CV pipeline inference.

Use Nano Banana when:

* generating UI mockup reference images
* generating design asset concepts
* producing visual style references for frontend components

Do NOT use Nano Banana for:

* exercise detection or classification
* pose validation
* any part of the CV pipeline

Example:

~/.bun/bin/bun ~/tools/nano-banana-2/src/cli.ts "dark health dashboard UI component" -o component-name -d design-system/mockups -s 1K -a 16:9

Note: Requires paid Gemini API key. Free tier has no image generation quota.
