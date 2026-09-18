#!/usr/bin/env python3
"""Read-only runtime content inventory against the pinned Toonflow source tree.

Uses the local PostgreSQL container; exports hashes and configuration identifiers,
never model credentials or project content. Does not run the content sync script.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

BASELINE = "cd3e7c4e83963bea255be2e621eb78d2cd1c2188"


def digest(content):
    return hashlib.sha256(content.encode()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--container", default="rust-toon-postgres")
    args = parser.parse_args()
    args.source = args.source.resolve()
    commit = subprocess.check_output(
        ["git", "-C", str(args.source), "rev-parse", "HEAD"], text=True
    ).strip()
    if commit != BASELINE:
        parser.error(f"expected baseline {BASELINE}, found {commit}")
    changed = subprocess.check_output(
        ["git", "-C", str(args.source), "status", "--porcelain", "--", "data/skills"], text=True
    ).strip()
    if changed:
        parser.error("baseline data/skills contains local changes; use a clean source checkout")

    def query(sql):
        result = subprocess.check_output(
            ["docker", "exec", "-i", args.container, "psql", "-X", "-v",
             "ON_ERROR_STOP=1", "-U", "rust_toon", "-d", "rust_toon", "-Atq"],
            input=f"BEGIN READ ONLY; SELECT coalesce(json_agg(t),'[]') FROM ({sql}) t; ROLLBACK;",
            text=True,
        )
        return json.loads(result)

    def compare(content, source):
        source = source.resolve()
        if not source.is_relative_to(args.source / "data" / "skills"):
            raise ValueError("content path is outside the baseline skills directory")
        exists = source.is_file()
        original = source.read_text(encoding="utf-8") if exists else ""
        # Match the whitespace normalization used by the existing importer.
        normalized = re.sub(r"[\t ]+$", "", original, flags=re.MULTILINE)
        return {
            "sha256": digest(content),
            "source": str(source.relative_to(args.source)),
            "sourceSha256": digest(original) if exists else None,
            "comparison": ("matches-baseline" if content in (original, normalized)
                           else "differs-from-baseline") if exists else "no-baseline-file",
            "userModification": "unknown; content difference does not establish authorship",
        }

    root = args.source / "data" / "skills"
    skills = query("SELECT path,name,content,state,md5,update_time FROM toonflow.skill_list ORDER BY path")
    for skill in skills:
        skill.update(compare(skill.pop("content"), root / skill["path"]))
    manuals = query("SELECT kind,path,name,data,update_time FROM toonflow.creative_manuals ORDER BY kind,path")
    for manual in manuals:
        group = root / ("art_skills" if manual["kind"] == "visual" else "story_skills") / manual["path"]
        entries = []
        for item in manual.pop("data"):
            key = item.get("value", "")
            subdir = "art_prompt" if key.startswith("art_") else "driector_skills" if key.startswith("director_") else ""
            entries.append({"value": key, **compare(item.get("data", ""), group / subdir / f"{key}.md")})
        manual["entries"] = entries
    report = {
        "baseline": {"repository": "HBAI-Ltd/Toonflow-app", "version": "v1.1.8", "commit": commit},
        "skills": skills,
        "manuals": manuals,
        "attributions": query("SELECT agent_key,skill_path,priority FROM toonflow.skill_attributions ORDER BY agent_key,priority"),
        "projects": query("SELECT id,art_style,director_manual,image_model,video_model,chat_model,mode FROM toonflow.projects ORDER BY id"),
        "agents": query("SELECT key,model_config_id,prompt_source_key,disabled FROM toonflow.agent_deployments ORDER BY key"),
        "models": query("SELECT id,key,name,platform,type,model FROM ai.model_configs ORDER BY id"),
        "modelPromptMaps": query("SELECT model_config_id,prompt_key,enabled FROM ai.model_prompt_maps ORDER BY model_config_id,id"),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Read-only inventory: {len(skills)} skills, {len(manuals)} manuals -> {args.output}")


if __name__ == "__main__":
    main()
