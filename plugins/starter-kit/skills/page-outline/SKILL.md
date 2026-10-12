---
name: page-outline
description: Outline the structure of an HTML page - its title, headings, navigation links, sections, forms, images and the CSS and JS files it loads. Use when the user asks to outline, map, summarize or "show the structure of" an HTML page or a site's pages.
---

<!--
  A skill is a folder in skills/ with a SKILL.md inside. Claude reads the
  `description` above to decide when to use the skill on its own, so it says
  WHEN to use it, with phrases a user might type. The body below is only
  loaded once the skill is used. You can put helper files (templates,
  scripts, reference notes) in the same folder and mention them here.
-->

# Page outline

Produce a short, scannable outline of one or more HTML pages.

## Steps

1. Find the page(s). If the user named a file, read it. If they named a folder
   or "the site", list its `.html` files and outline each one.
2. For each page, report:
   - **Title**: the `<title>` text, or "missing".
   - **Headings**: the `h1`-`h3` tree, indented by level.
   - **Navigation**: each link in `<nav>` (or the first list of links) with its
     target, and mark any that point to a local file that does not exist.
   - **Sections**: the main landmark elements (`header`, `main`, `section`,
     `article`, `aside`, `footer`) in order.
   - **Forms**: each form's fields and what it submits to.
   - **Images**: count, and how many have no `alt` text.
   - **Assets**: the stylesheets and scripts it loads, and whether each local
     one exists.
3. End with at most three suggestions, most useful first. Skip this if there
   is nothing worth fixing.

Keep each page's outline under about 30 lines. Do not edit any files.
