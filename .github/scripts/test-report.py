import glob
import os
import sys
import xml.etree.ElementTree as ElementTree
from collections import defaultdict

results_dir = sys.argv[1]
exit_code = sys.argv[2] if len(sys.argv) > 2 else ""
sha = os.environ.get("HEAD_SHA", "")[:7]
run_url = os.environ.get("RUN_URL", "")

passed, failed, skipped = [], [], []
for path in sorted(glob.glob(os.path.join(results_dir, "*.xml"))):
    try:
        root = ElementTree.parse(path).getroot()
    except ElementTree.ParseError:
        continue
    for case in root.iter("testcase"):
        suite = case.get("classname", "").split(".")[-1]
        name = case.get("name", "")
        problem = case.find("failure")
        if problem is None:
            problem = case.find("error")
        if problem is not None:
            message = (problem.get("message") or problem.text or "").strip().splitlines()
            failed.append((suite, name, message[0] if message else ""))
        elif case.find("skipped") is not None:
            skipped.append((suite, name))
        else:
            passed.append((suite, name))


def cell(text):
    return text.replace("|", "\\|").replace("\n", " ")[:300]


def grouped(cases):
    groups = defaultdict(list)
    for suite, name in cases:
        groups[suite].append(name)
    lines = []
    for suite in sorted(groups):
        lines.append(f"**{suite}**")
        lines.extend(f"- {name}" for name in sorted(groups[suite]))
        lines.append("")
    return lines


crashed = exit_code not in ("", "0") and not failed
icon = "❌" if failed or crashed else "✅"
summary = f"{len(passed)} passed, {len(failed)} failed"
if skipped:
    summary += f", {len(skipped)} skipped"

lines = [f"### {icon} Swift tests: {summary}", ""]
details = []
if sha:
    details.append(f"Commit `{sha}`")
if run_url:
    details.append(f"[Workflow run]({run_url})")
if details:
    lines += [" · ".join(details), ""]

if crashed:
    lines += [
        f"> **The test run exited with code {exit_code} without reporting a failing test.** "
        "It probably crashed or failed to build; check the workflow log.",
        "",
    ]

if failed:
    lines += ["#### Failed", "", "| Suite | Test | Message |", "| --- | --- | --- |"]
    lines += [f"| {cell(suite)} | {cell(name)} | {cell(message)} |" for suite, name, message in sorted(failed)]
    lines.append("")

if passed:
    lines += [f"<details><summary>Passed ({len(passed)})</summary>", ""]
    lines += grouped(passed)
    lines += ["</details>", ""]

if skipped:
    lines += [f"<details><summary>Skipped ({len(skipped)})</summary>", ""]
    lines += grouped(skipped)
    lines += ["</details>", ""]

if not passed and not failed and not skipped:
    lines += ["No test results were found.", ""]

print("\n".join(lines))
