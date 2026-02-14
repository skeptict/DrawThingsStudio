# Workflow Execution — How It Works

## Overview

The workflow executor (`StoryflowExecutor`) runs workflows by processing instructions one at a time. Most instructions only **set local state** (prompt text, config values, canvas image). Only three instructions actually **trigger Draw Things to generate an image**.

## The Key Concept: State vs. Triggers

### State-Setting Instructions (do NOT call Draw Things)

These instructions build up the executor's internal state. They run instantly and report "success", but nothing is sent to Draw Things:

| Instruction | What It Does |
|---|---|
| `prompt` | Stores the prompt text in state |
| `negativePrompt` | Stores the negative prompt in state |
| `config` | Merges config values (width, height, steps, model, etc.) into state |
| `frames` | Sets the frame count in state |
| `canvasLoad` | Loads an image file from the working directory into the canvas |
| `note` | No-op (ignored) |

**This is why a workflow with only `prompt` + `config` finishes instantly — nothing triggers generation.**

### Generation Trigger Instructions (DO call Draw Things)

These are the only instructions that send an API call to Draw Things:

| Instruction | Behavior |
|---|---|
| **`canvasSave`** | Generates an image, saves it to a file in the working directory, and stores the result on the internal canvas. |
| **`generate`** | Generates an image, stores it on the internal canvas and displays it in the image panel. Does NOT save to disk. |
| **`loopSave`** | Same as `canvasSave` but with an auto-incrementing filename (for use inside loops). |

### How Generation Mode Is Determined

When a trigger fires, the executor decides what to do based on internal state:

| Canvas State | Mask State | Prompt | Mode |
|---|---|---|---|
| Empty | Empty | Set | **txt2img** — generates from prompt only |
| Has image | Empty | Set | **img2img** — transforms the canvas image using the prompt |
| Has image | Has mask | Set | **inpainting** — regenerates masked region |
| Empty | Any | Empty | **Error** — "No prompt or canvas to save" |

## Common Workflow Patterns

### Text-to-Image (simplest)

```
1. Config        → sets dimensions, steps, model, etc.
2. Prompt        → sets the prompt text
3. Save Canvas   → TRIGGERS generation, saves result as output.png
```

### Image-to-Image

```
1. Config        → sets dimensions, steps, strength, etc.
2. Load Canvas   → loads source image into canvas state
3. Prompt        → sets the prompt text
4. Save Canvas   → TRIGGERS img2img generation (because canvas has an image)
```

### Image-to-Video (i2v)

```
1. Config        → set model to a video model, set frames, etc.
2. Load Canvas   → loads source image into canvas state
3. Prompt        → sets the prompt describing the motion/video
4. Save Canvas   → TRIGGERS generation via Draw Things (which uses the video model)
```

**Note:** The executor itself doesn't distinguish between image and video models. It sends the request to Draw Things, which handles the generation based on whatever model is currently loaded. The `frames` instruction sets a frame count in state, but the actual video generation behavior depends on Draw Things and the loaded model.

### Generate Without Saving

```
1. Config        → sets dimensions, steps, model, etc.
2. Prompt        → sets the prompt text
3. Generate      → TRIGGERS generation, result shown in image panel (no file saved)
```

Use `Generate Image` instead of `Save Canvas` when you just want to see the result without writing a file.

### Batch Variations (loop)

```
1. Config        → sets dimensions, steps, model, etc.
2. Prompt        → sets the prompt text
3. Loop (5)      → repeat 5 times:
4.   Loop Save   →   TRIGGERS generation, saves as variation_0.png, variation_1.png, ...
5. Loop End      → end loop
```

### Batch Folder Processing (img2img loop)

```
1. Config        → sets strength, steps, etc.
2. Prompt        → sets the enhancement prompt
3. Loop (N)      → repeat for each file:
4.   Loop Load   →   loads next image from input folder into canvas
5.   Loop Save   →   TRIGGERS img2img, saves as output_0.png, output_1.png, ...
6. Loop End      → end loop
```

## The Missing Trigger Warning

If a workflow has no `canvasSave`, `loopSave`, or `generate` instruction, the execution preview shows an orange warning banner:

> "This workflow has no generation trigger. Add a 'Save Canvas', 'Loop Save', or 'Generate Image' instruction to generate images via Draw Things."

The **Execute** button is also disabled in this case, with a tooltip explaining why.

## Working Directory

All file paths in `canvasLoad`, `canvasSave`, and `loopLoad`/`loopSave` are relative to the **working directory**. The default is:

```
~/Library/Containers/tanque.org.DrawThingsStudio/Data/Library/Application Support/DrawThingsStudio/WorkflowOutput/
```

You can change the working directory using the folder button in the execution view header before running the workflow. Note: the app is sandboxed, so only directories the app has been granted access to will work.

## What the Executor Does NOT Do

- It does not load or switch models in Draw Things — it sends the model name in the config, but Draw Things must already have that model available.
- It does not handle canvas manipulation (`canvasClear`, `moveScale`, `adaptSize`, `crop`) — these require Draw Things internal state and are skipped.
- It does not use moodboard references — images can be tracked locally but the API doesn't send moodboard data.
- It does not run mask detection (`maskBackground`, `maskForeground`, `maskBody`, `maskAsk`) — these require Draw Things internals.
