"""
Gemini Prompts for Blog Image Generator

Prompts for analyzing blog content and generating visuals.
"""

from config import HOMELAB_CONTEXT

# ============================================================================
# ANALYSIS PROMPT
# ============================================================================

ANALYSIS_PROMPT = '''Analyze this blog post section and determine if it needs a visual element.

Section Content:
{section_content}

Post Title: {post_title}
Section Number: {section_index}

Context: This is from a homelab blog series about infrastructure, networking, and automation.

{homelab_context}

Rules for determining visual needs:
1. MERMAID DIAGRAM - Use for:
   - Architecture descriptions (network topology, service layout)
   - Workflow/process descriptions (deployment steps, data flow)
   - Component relationships (how services connect)
   - Before/after comparisons with structure

2. AI IMAGE - Use for:
   - Opening sections that set mood/theme (conceptual illustration)
   - Abstract concepts that benefit from artistic representation
   - Sections describing physical setup or environment

3. NONE - Use for:
   - Short transitional paragraphs
   - Conclusions or summaries
   - Sections that are already clear without visuals
   - Code-heavy sections (code IS the visual)

Respond with ONLY valid JSON (no markdown, no explanation):
{{
  "needs_visual": true or false,
  "visual_type": "mermaid_diagram" or "ai_image" or "none",
  "description": "Detailed description of what the visual should show",
  "mermaid_type": "flowchart" or "sequence" or "graph" or "stateDiagram" (only if mermaid_diagram),
  "insertion_point": "before" or "after",
  "reasoning": "Brief explanation of why this visual type was chosen"
}}'''

# ============================================================================
# MERMAID GENERATION PROMPT
# ============================================================================

MERMAID_PROMPT = '''Generate a Mermaid.js diagram based on this description.

Description: {description}
Diagram Type: {mermaid_type}
Blog Context: {post_title}

{homelab_context}

Requirements:
1. Use clear, readable labels (not too long)
2. Include relevant components from the description
3. Keep it focused - don't overcomplicate
4. Use proper Mermaid syntax for {mermaid_type}
5. Use subgraphs to group related components
6. Include IP addresses or ports where relevant

Output ONLY the Mermaid code starting with ```mermaid and ending with ```.
No explanations, no additional text.

Example format:
```mermaid
graph TB
    A[Component] --> B[Component]
```'''

# ============================================================================
# AI IMAGE PROMPT
# ============================================================================

AI_IMAGE_PROMPT = '''Generate a technical illustration for a homelab blog post.

Description: {description}
Blog Post: {post_title}
Section Context: {section_context}

Style Guidelines:
- Clean, modern, technical illustration style
- Color palette: Deep blues, purples, teals (dark theme friendly)
- Elements to include: Server racks, network cables, glowing LEDs, terminal windows, dashboard screens
- Mood: Professional, educational, slightly futuristic
- Perspective: Isometric or slight 3D angle preferred

Important:
- Do NOT include any text, labels, or words in the image
- Focus on visual storytelling
- Make it suitable as a blog header or section illustration
- Resolution: 1200x630 pixels (blog header ratio)

Generate the image now.'''

# ============================================================================
# BATCH ANALYSIS PROMPT (for processing entire post at once)
# ============================================================================

BATCH_ANALYSIS_PROMPT = '''Analyze this entire blog post and identify ALL sections that need visual elements.

Blog Post Title: {post_title}
Full Content:
{full_content}

{homelab_context}

For each section that needs a visual, provide details.

Respond with ONLY valid JSON array (no markdown, no explanation):
[
  {{
    "section_index": 0,
    "section_preview": "First 50 chars of the section...",
    "needs_visual": true,
    "visual_type": "mermaid_diagram",
    "description": "What the diagram should show",
    "mermaid_type": "flowchart",
    "insertion_point": "after"
  }},
  ...
]

Only include sections that NEED visuals. Skip sections that are fine without them.
Aim for 2-4 visuals per blog post - don't over-visualize.'''


def get_analysis_prompt(section_content: str, post_title: str, section_index: int) -> str:
    """Build the analysis prompt for a single section."""
    return ANALYSIS_PROMPT.format(
        section_content=section_content,
        post_title=post_title,
        section_index=section_index,
        homelab_context=HOMELAB_CONTEXT
    )


def get_mermaid_prompt(description: str, mermaid_type: str, post_title: str) -> str:
    """Build the Mermaid generation prompt."""
    return MERMAID_PROMPT.format(
        description=description,
        mermaid_type=mermaid_type,
        post_title=post_title,
        homelab_context=HOMELAB_CONTEXT
    )


def get_image_prompt(description: str, post_title: str, section_context: str) -> str:
    """Build the AI image generation prompt."""
    return AI_IMAGE_PROMPT.format(
        description=description,
        post_title=post_title,
        section_context=section_context
    )


def get_batch_analysis_prompt(post_title: str, full_content: str) -> str:
    """Build the batch analysis prompt for entire post."""
    return BATCH_ANALYSIS_PROMPT.format(
        post_title=post_title,
        full_content=full_content,
        homelab_context=HOMELAB_CONTEXT
    )
