---
title: LLM skills
layout: default
nav_order: 10
permalink: /docs/llm-skills/
description: Download or copy a skill file for LLMs to help write Little Physics C# and ECS code.
tags: [llm, skills, ai]
---

# LLM skills

This is a **skill set you can give to your LLM** (ChatGPT, Claude, Cursor, Copilot, or similar) when writing **C# and ECS code** for **Little Physics**. Paste it into a custom instruction, project rule, or agent skill so the model knows package requirements, pipeline hook points, custom jobs, builders, native buffer rules, and common pitfalls.


## Skill file

Source: [`assets/files/skill.txt`]({{ '/assets/files/skill.txt' | relative_url }}) — plain text, copied as-is by Jekyll (Download saves as `.md`).

{% assign skill_file_url = '/assets/files/skill.txt' | relative_url %}
{% include skill-file-block.html url=skill_file_url filename="little-physics-skill.md" %}
