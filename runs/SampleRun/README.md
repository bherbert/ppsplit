# SampleRun

A sample session demonstrating the full Peace Pi Video Splitter workflow.

**YouTube video:** https://www.youtube.com/watch?v=DRNqPRj8wcw

---

## Workflow Steps

**Step 0 — This folder is your session folder.**

`runs/SampleRun/` is already created and ready. All downloaded video, extracted clips, and the log file will land here.

**Step 1 — Fetch the YouTube video.**

Right-click the `SampleRun` folder in Finder and run:

> **Peace Pi Video Splitter - 1) Fetch YouTube video**

When prompted, paste this URL:

```
https://www.youtube.com/watch?v=DRNqPRj8wcw
```

The video will download into this folder as an `.mp4` file.

**Step 2 — Review `snippets.csv.txt`.**

A `snippets.csv.txt` file is already provided in this folder with two sample clips pre-defined:

```
# start-timestamp, end-timestamp, video-name
2:00,2:29,Random1
3:15,3:33,Random2
```

Edit it if you want different timestamps or titles. If starting fresh, right-click the `SampleRun` folder and run:

> **Peace Pi Video Splitter - 2) Create snippets CSV file**

**Step 3 — Extract the clips.**

Right-click the downloaded `.mp4` file (not the folder) and run:

> **Peace Pi Video Splitter - 3) Extract snippets from video**

Two clips will be extracted and saved to this folder:
- `Random1.mp4` — 2:00 to 2:29
- `Random2.mp4` — 3:15 to 3:33

A sound plays and a desktop notification appears when extraction completes. Check `ppsplit.log` for the full run summary.
