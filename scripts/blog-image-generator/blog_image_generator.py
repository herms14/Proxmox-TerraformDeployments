#!/usr/bin/env python3
"""
Blog Image Generator

Analyzes homelab blog posts and generates visual content:
- Mermaid.js diagrams for technical/architecture content
- AI images for conceptual/artistic content (optional)

Uses Gemini CLI for AI processing (requires `gemini` to be installed and authenticated).
"""

import argparse
import json
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

# Add script directory to path for imports
sys.path.insert(0, str(Path(__file__).parent))

from config import (
    BLOG_POSTS_PATH,
    OBSIDIAN_IMAGES_PATH,
    HUGO_IMAGES_PATH,
    HUGO_REPO_PATH,
    SYNC_TO_HUGO,
    DRY_RUN,
    GEMINI_TIMEOUT,
    ensure_directories,
    get_post_files,
)
from prompts import (
    get_analysis_prompt,
    get_mermaid_prompt,
    get_batch_analysis_prompt,
)


@dataclass
class VisualAnalysis:
    """Result of analyzing a section for visual needs."""
    needs_visual: bool
    visual_type: str  # "mermaid_diagram", "ai_image", "none"
    description: str
    mermaid_type: Optional[str] = None
    insertion_point: str = "after"
    reasoning: str = ""


@dataclass
class BlogPost:
    """Parsed blog post."""
    file_path: Path
    title: str
    front_matter: str
    sections: list[str]
    raw_content: str


def parse_blog_post(file_path: Path) -> BlogPost:
    """Parse a blog post into front matter and sections."""
    content = file_path.read_text(encoding="utf-8")

    # Extract front matter
    front_matter_match = re.match(r"^---\n(.*?)\n---\n", content, re.DOTALL)
    if front_matter_match:
        front_matter = front_matter_match.group(0)
        body = content[len(front_matter):]
    else:
        front_matter = ""
        body = content

    # Extract title from front matter
    title_match = re.search(r'title:\s*["\']?([^"\'\n]+)["\']?', front_matter)
    title = title_match.group(1) if title_match else file_path.stem

    # Split into sections by horizontal rule
    sections = re.split(r"\n---\n", body)
    sections = [s.strip() for s in sections if s.strip()]

    return BlogPost(
        file_path=file_path,
        title=title,
        front_matter=front_matter,
        sections=sections,
        raw_content=content,
    )


def get_gemini_command() -> list[str]:
    """Get the correct gemini CLI command for the current platform."""
    import platform
    if platform.system() == "Windows":
        # On Windows, use full path to gemini.cmd
        npm_path = Path.home() / "AppData" / "Roaming" / "npm" / "gemini.cmd"
        if npm_path.exists():
            return [str(npm_path)]
        # Fallback to using cmd /c to find it in PATH
        return ["cmd", "/c", "gemini"]
    return ["gemini"]


def call_gemini(prompt: str, timeout: int = GEMINI_TIMEOUT) -> str:
    """Call Gemini CLI with a prompt and return the response."""
    import tempfile
    gemini_cmd = get_gemini_command()

    # Write prompt to temp file to handle long prompts with special chars
    with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False, encoding='utf-8') as f:
        f.write(prompt)
        prompt_file = f.name

    try:
        # Read prompt from stdin to handle long prompts properly
        with open(prompt_file, 'r', encoding='utf-8') as f:
            prompt_content = f.read()

        # Use gemini CLI with prompt piped via stdin
        result = subprocess.run(
            gemini_cmd + ["-o", "json"],
            input=prompt_content,
            capture_output=True,
            text=True,
            timeout=timeout,
            encoding="utf-8",
        )

        if result.returncode != 0:
            print(f"  [ERROR] Gemini CLI error (code {result.returncode})")
            print(f"  [ERROR] stderr: {result.stderr[:500] if result.stderr else 'None'}")
            print(f"  [ERROR] stdout: {result.stdout[:500] if result.stdout else 'None'}")
            return ""

        # Parse JSON output
        try:
            output = json.loads(result.stdout)
            response = output.get("response", "")
            if not response:
                print(f"  [DEBUG] Empty response from Gemini")
                print(f"  [DEBUG] Full output: {result.stdout[:500]}")
            return response
        except json.JSONDecodeError:
            # Sometimes output isn't valid JSON, return raw
            print(f"  [DEBUG] Non-JSON response: {result.stdout[:200]}")
            return result.stdout

    except subprocess.TimeoutExpired:
        print(f"  [ERROR] Gemini CLI timed out after {timeout}s")
        return ""
    except FileNotFoundError:
        print("  [ERROR] Gemini CLI not found. Install with: npm install -g @google/gemini-cli")
        return ""
    finally:
        # Cleanup temp file
        import os
        try:
            os.unlink(prompt_file)
        except:
            pass


def analyze_section(section: str, post_title: str, section_index: int) -> Optional[VisualAnalysis]:
    """Analyze a section to determine if it needs a visual."""
    prompt = get_analysis_prompt(section, post_title, section_index)
    response = call_gemini(prompt)

    if not response:
        return None

    # Try to parse JSON from response
    try:
        # Find JSON in response (might have extra text)
        json_match = re.search(r"\{.*\}", response, re.DOTALL)
        if json_match:
            data = json.loads(json_match.group())
            return VisualAnalysis(
                needs_visual=data.get("needs_visual", False),
                visual_type=data.get("visual_type", "none"),
                description=data.get("description", ""),
                mermaid_type=data.get("mermaid_type"),
                insertion_point=data.get("insertion_point", "after"),
                reasoning=data.get("reasoning", ""),
            )
    except json.JSONDecodeError:
        print(f"  [WARN] Could not parse analysis response as JSON")

    return None


def generate_mermaid(description: str, mermaid_type: str, post_title: str) -> Optional[str]:
    """Generate a Mermaid diagram using Gemini."""
    prompt = get_mermaid_prompt(description, mermaid_type, post_title)
    response = call_gemini(prompt)

    if not response:
        return None

    # Extract Mermaid code block
    mermaid_match = re.search(r"```mermaid\n(.*?)```", response, re.DOTALL)
    if mermaid_match:
        return mermaid_match.group(0)

    # Try to find just the diagram code
    if response.strip().startswith(("graph ", "flowchart ", "sequenceDiagram", "stateDiagram")):
        return f"```mermaid\n{response.strip()}\n```"

    print(f"  [WARN] Could not extract Mermaid diagram from response")
    return None


def insert_visual_into_section(section: str, visual: str, insertion_point: str = "after") -> str:
    """Insert a visual (Mermaid or image reference) into a section."""
    if insertion_point == "before":
        return f"{visual}\n\n{section}"
    else:
        return f"{section}\n\n{visual}"


def process_blog_post(file_path: Path, dry_run: bool = False, mermaid_only: bool = True) -> dict:
    """Process a single blog post and generate visuals."""
    print(f"\n{'='*60}")
    print(f"Processing: {file_path.name}")
    print(f"{'='*60}")

    post = parse_blog_post(file_path)
    print(f"Title: {post.title}")
    print(f"Sections: {len(post.sections)}")

    results = {
        "file": str(file_path),
        "title": post.title,
        "sections_analyzed": 0,
        "visuals_added": 0,
        "mermaid_diagrams": 0,
        "ai_images": 0,
        "errors": [],
    }

    modified_sections = []

    for i, section in enumerate(post.sections):
        print(f"\n--- Section {i+1}/{len(post.sections)} ---")
        preview = section[:100].replace("\n", " ")
        print(f"Preview: {preview}...")

        # Analyze section
        print("  Analyzing with Gemini...")
        analysis = analyze_section(section, post.title, i)
        results["sections_analyzed"] += 1

        if analysis is None:
            print("  [SKIP] Analysis failed")
            modified_sections.append(section)
            continue

        if not analysis.needs_visual:
            print(f"  [SKIP] No visual needed: {analysis.reasoning}")
            modified_sections.append(section)
            continue

        print(f"  [VISUAL] Type: {analysis.visual_type}")
        print(f"  [VISUAL] Description: {analysis.description[:80]}...")

        if analysis.visual_type == "mermaid_diagram":
            print(f"  Generating Mermaid ({analysis.mermaid_type})...")
            mermaid_code = generate_mermaid(
                analysis.description,
                analysis.mermaid_type or "flowchart",
                post.title
            )

            if mermaid_code:
                print(f"  [SUCCESS] Mermaid diagram generated")
                if not dry_run:
                    section = insert_visual_into_section(
                        section, mermaid_code, analysis.insertion_point
                    )
                results["mermaid_diagrams"] += 1
                results["visuals_added"] += 1
            else:
                results["errors"].append(f"Section {i}: Mermaid generation failed")

        elif analysis.visual_type == "ai_image" and not mermaid_only:
            # AI image generation - placeholder for future implementation
            print(f"  [SKIP] AI image generation not yet implemented")
            # TODO: Implement using gemini-imagen or Gemini 2.5 Flash Image

        modified_sections.append(section)

    # Reconstruct the blog post
    if results["visuals_added"] > 0 and not dry_run:
        new_content = post.front_matter + "\n---\n".join(modified_sections)

        print(f"\n--- Writing Changes ---")
        print(f"  Output: {file_path}")

        # Backup original
        backup_path = file_path.with_suffix(".md.bak")
        shutil.copy(file_path, backup_path)
        print(f"  Backup: {backup_path}")

        # Write updated content
        file_path.write_text(new_content, encoding="utf-8")
        print(f"  [SAVED] {results['visuals_added']} visuals added")

    return results


def process_all_posts(dry_run: bool = False, mermaid_only: bool = True) -> list[dict]:
    """Process all blog posts."""
    ensure_directories()
    post_files = get_post_files()

    print(f"Found {len(post_files)} blog posts")

    all_results = []
    for file_path in post_files:
        results = process_blog_post(file_path, dry_run, mermaid_only)
        all_results.append(results)

    return all_results


def print_summary(results: list[dict]):
    """Print a summary of processing results."""
    print(f"\n{'='*60}")
    print("PROCESSING SUMMARY")
    print(f"{'='*60}")

    total_posts = len(results)
    total_sections = sum(r["sections_analyzed"] for r in results)
    total_visuals = sum(r["visuals_added"] for r in results)
    total_mermaid = sum(r["mermaid_diagrams"] for r in results)
    total_images = sum(r["ai_images"] for r in results)
    total_errors = sum(len(r["errors"]) for r in results)

    print(f"Posts processed:    {total_posts}")
    print(f"Sections analyzed:  {total_sections}")
    print(f"Visuals added:      {total_visuals}")
    print(f"  - Mermaid:        {total_mermaid}")
    print(f"  - AI Images:      {total_images}")
    print(f"Errors:             {total_errors}")

    if total_errors > 0:
        print(f"\nErrors:")
        for r in results:
            for error in r["errors"]:
                print(f"  - {r['title']}: {error}")


def main():
    parser = argparse.ArgumentParser(
        description="Generate visual content for homelab blog posts using Gemini"
    )
    parser.add_argument(
        "--post", "-p",
        type=str,
        help="Process a single post (filename or full path)"
    )
    parser.add_argument(
        "--all", "-a",
        action="store_true",
        help="Process all blog posts"
    )
    parser.add_argument(
        "--dry-run", "-n",
        action="store_true",
        help="Preview changes without writing files"
    )
    parser.add_argument(
        "--mermaid-only", "-m",
        action="store_true",
        default=True,
        help="Only generate Mermaid diagrams (skip AI images)"
    )
    parser.add_argument(
        "--include-images", "-i",
        action="store_true",
        help="Include AI image generation (experimental)"
    )
    parser.add_argument(
        "--list", "-l",
        action="store_true",
        help="List available blog posts"
    )

    args = parser.parse_args()

    # Determine mermaid_only setting
    mermaid_only = not args.include_images

    if args.list:
        post_files = get_post_files()
        print(f"Available blog posts ({len(post_files)}):\n")
        for f in post_files:
            print(f"  {f.name}")
        return

    if args.post:
        # Process single post
        post_path = Path(args.post)
        if not post_path.is_absolute():
            post_path = BLOG_POSTS_PATH / args.post

        if not post_path.exists():
            print(f"Error: Post not found: {post_path}")
            sys.exit(1)

        results = process_blog_post(post_path, args.dry_run, mermaid_only)
        print_summary([results])

    elif args.all:
        # Process all posts
        results = process_all_posts(args.dry_run, mermaid_only)
        print_summary(results)

    else:
        parser.print_help()


if __name__ == "__main__":
    main()
