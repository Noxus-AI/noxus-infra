#!/usr/bin/env python3
"""
Flattens mod/*.tf into a single self-contained root configuration at
flat/main.tf, for handing someone one file instead of a module tree.

The output lands in its own directory on purpose: Terraform loads every *.tf
in a directory, so a flattened copy sitting next to main.tf would redeclare
every variable and resource and break `terraform init`.
"""

import re
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
MOD_DIR = SCRIPT_DIR / "mod"
OUTPUT_DIR = SCRIPT_DIR / "flat"
OUTPUT_FILE = OUTPUT_DIR / "main.tf"

# Order matters for readability: foundational resources first, then dependents
FILE_ORDER = [
    "versions.tf",
    "main.tf",
    "variables.tf",
    "network.tf",
    "identity.tf",
    "acr.tf",
    "postgres.tf",
    "redis.tf",
    "storage.tf",
    "secrets.tf",
    "keyvault.tf",
    "container_apps.tf",
    "outputs.tf",
]

# mod/ declares no provider — the root that consumes it does. The flattened
# file *is* a root, so it needs one.
PROVIDER_BLOCK = """provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}"""


def read_mod_files() -> list[tuple[str, str]]:
    """Read all .tf files from mod/ in the defined order."""
    sections = []
    seen = set()

    for filename in FILE_ORDER:
        filepath = MOD_DIR / filename
        if filepath.exists():
            sections.append((filename, filepath.read_text()))
            seen.add(filename)

    # Pick up any .tf files not in the explicit order list
    for filepath in sorted(MOD_DIR.glob("*.tf")):
        if filepath.name not in seen:
            sections.append((filepath.name, filepath.read_text()))

    return sections


def build_output(sections: list[tuple[str, str]]) -> str:
    """Combine all sections into a single .tf file with divider comments."""
    parts = [
        "# ==========================================================================",
        "# Auto-generated flattened Terraform configuration — DO NOT EDIT.",
        "# Source: terraform/stacks/serverless/azure-containerapps/mod/*.tf",
        "# Regenerate with: python terraform/stacks/serverless/azure-containerapps/generate_tf.py",
        "# ==========================================================================",
        "",
        "# -------------------------- PROVIDER --------------------------",
        PROVIDER_BLOCK,
        "",
    ]

    for filename, content in sections:
        label = filename.replace(".tf", "").replace("_", " ").upper()
        parts.append(
            f"# -------------------------- {label} ({filename}) --------------------------"
        )
        parts.append(content.strip())
        parts.append("")

    return "\n".join(parts) + "\n"


def main():
    if not MOD_DIR.is_dir():
        print(f"Error: {MOD_DIR} does not exist")
        raise SystemExit(1)

    sections = read_mod_files()
    if not sections:
        print("Error: no .tf files found in mod/")
        raise SystemExit(1)

    output = build_output(sections)
    OUTPUT_DIR.mkdir(exist_ok=True)
    OUTPUT_FILE.write_text(output)

    total_resources = sum(
        len(re.findall(r'^resource\s+"', content, re.MULTILINE))
        for _, content in sections
    )
    print(f"Generated {OUTPUT_FILE.relative_to(SCRIPT_DIR)}")
    print(f"  Sources: {len(sections)} files from mod/")
    print(f"  Resources: {total_resources} resource blocks")
    print(f"  Size: {len(output)} bytes")


if __name__ == "__main__":
    main()
