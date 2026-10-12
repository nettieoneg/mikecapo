---
description: Greet someone and list what the starter-kit plugin can do
argument-hint: "[name]"
---

<!--
  A slash command is a Markdown file in commands/. The file name becomes the
  command: this one runs as /starter-kit:hello (or /hello if no other plugin
  uses that name). Everything below the frontmatter is the prompt Claude gets.
  $ARGUMENTS is replaced with whatever the user typed after the command.
-->

Say hello to $ARGUMENTS (if no name was given, greet "friend").

Then, in three short bullet points, tell them what this plugin includes:

- the `page-outline` skill, which outlines an HTML page's structure
- the `code-explainer` agent, which walks through a JavaScript file for a beginner
- a hook that checks HTML files after they are edited for a missing `<title>` and images without `alt` text

Keep the whole reply under 80 words.
