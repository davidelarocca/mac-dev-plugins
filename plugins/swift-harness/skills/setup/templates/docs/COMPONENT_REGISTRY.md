# Component registry

One entry per shared component or behavior. Updated in the same change as the code, never later.
Read this before adding any UI element.

Checked at the end of every turn that changes code: each File must exist and declare the Name, IDs and
names are unique, a Retired ID is no longer under Components. File holds paths from the repository root,
comma-separated. Write a literal pipe inside a cell as `\|`. Keep the column headers.

## Components

| ID | Name | Purpose | Use when | Don't use when | API entry point | File | Used by | Tests |
|---|---|---|---|---|---|---|---|---|
| UI-001 | | | | | | | | previews / snapshot / unit |

## Internal

Views, modifiers and styles in the design system that are not meant for reuse by features (galleries,
building blocks of a registered component). Listed here so they are not reported as missing.

| Name | Why not registered |
|---|---|

## To consolidate

Duplicates or near-duplicates found in the code that still need to be merged into a shared component.

| Element | Locations | Differences | Plan |
|---|---|---|---|

## Retired

Components removed or replaced, with what replaced them.

| ID | Replaced by | Date |
|---|---|---|
