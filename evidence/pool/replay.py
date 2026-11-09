"""Replay the pool validation run in ~15 minutes.

Copies this example to a temp dir (the replay writes acceptance records; the
example stays pristine), then walks the whole arc through the installed engine:

1. export the acceptance scenarios from the TLA+ spec,
2. run the Alloy checks and TLC,
3. accept all scenarios from the answers file (the in-chat approvals, transcribed),
4. close ``forge_done``,
5. print the tutorial walkthrough of both specs.

Requires: specforge-engine installed, Java 17+.
"""

import asyncio
import json
import shutil
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent


def _tool(server, name):
    return server._tool_manager._tools[name].fn


def main() -> int:
    from specforge_engine.mcp.server import build_server

    work = Path(tempfile.mkdtemp(prefix="pool-replay-"))
    for f in ("requirements.md", "Pool.tla", "Pool.cfg", "pool.als"):
        shutil.copy(HERE / f, work / f)
    shutil.copytree(HERE / "scenarios", work / "scenarios")
    shutil.copytree(HERE / ".specforge", work / ".specforge")
    root = str(work)
    print(f"# working copy: {root}\n")
    server = build_server(prerequisite_problems=[])

    print("## 1. requirements")
    reqs = (work / "requirements.md").read_text().splitlines()
    print(f"{len([l for l in reqs if l[:1] == 'R' or l.startswith('NFR')])} numbered requirements\n")

    print("## 2. scenarios + checkers")
    sc = _tool(server, "export_acceptance_scenarios")(module=str(work / "Pool.tla"),
                                                     cfg=str(work / "Pool.cfg"), out_dir=str(work / "out"))
    print(f"exported {len(sc['scenarios'])} scenarios: {', '.join(sc['scenarios'])}")
    alloy = _tool(server, "alloy_check")(model=str(work / "pool.als"))
    # the strict gate refuses: exactly the two intentional impossibility proofs
    # (WaitBelowCapacity, ShutdownWithWaiters) are UNSAT — that refusal IS the verdict
    alloy_ok = alloy.get("refused") == "OverconstrainedModel" and all(
        n in alloy.get("reason", "") for n in ("WaitBelowCapacity", "ShutdownWithWaiters"))
    if alloy_ok:
        print("alloy: overconstrained on exactly the 2 intentional impossibility proofs (expected)")
    else:
        print("alloy:", json.dumps(alloy)[:300])
    tla = _tool(server, "tla_check")(module=str(work / "Pool.tla"), cfg=str(work / "Pool.cfg"))
    print("tla:", tla.get("verdict", json.dumps(tla)[:200]), "\n")

    print("## 3. accept + close the gate")
    accept = asyncio.run(_tool(server, "accept_scenarios")(root=root, module="Pool.tla", cfg="Pool.cfg"))
    print("accept:", accept)
    done = _tool(server, "forge_done")(root=root, module="Pool.tla", cfg="Pool.cfg",
                                       requirements=str(work / "requirements.md"))
    print("forge_done:", done, "\n")

    print("## 4. tutorial: TLA+ goal + tour")
    tut = _tool(server, "tutorial_spec")(root=root, module="Pool.tla", cfg="Pool.cfg")
    for g in tut["goal"]:
        print(f"- [{g['kind']}] {g['name']}: {g['claim'] or '(carries %s)' % ','.join(g['req'])}")
    print("variables:", ", ".join(v["name"] for v in tut["variables"]))
    print("requirements quoted:", [q["id"] for q in tut["requirements"]["quotes"]])
    print("offer:", tut["offer"], "\n")

    print("## 5. tutorial: Alloy goal")
    tut_a = _tool(server, "tutorial_spec")(root=root, model="pool.als")
    for g in tut_a["goal"]:
        print(f"- {g['name']}: {g['claim'] or '(no claim comment)'}")
    print("paragraphs:", len(tut_a["paragraphs"]))
    ok = done.get("done") is True and accept.get("unaccepted") == [] and alloy_ok
    print(f"\n# replay {'GREEN' if ok else 'FAILED'}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
