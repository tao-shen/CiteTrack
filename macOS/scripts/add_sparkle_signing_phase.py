#!/usr/bin/env python3
"""
Add a build phase script to sign Sparkle framework components with entitlements.
This script modifies the Xcode project.pbxproj file to add a Run Script phase.
"""

import re
import sys
import uuid

PROJECT_FILE = "CiteTrack_macOS.xcodeproj/project.pbxproj"

def generate_uuid():
    """Generate a 24-character hex UUID for Xcode project format."""
    return ''.join([format(ord(c), 'x') for c in uuid.uuid4().hex[:12]])

def add_build_phase_script(project_path):
    """Add a Run Script phase to sign Sparkle components."""
    
    with open(project_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Check if script phase already exists
    if 'sign_sparkle_components.sh' in content:
        print("✅ Build script phase already exists")
        return
    
    # Generate UUIDs for the new objects
    script_phase_uuid = generate_uuid()
    script_uuid_ref = generate_uuid()
    
    # Find the target's buildPhases section
    target_pattern = r'(1290956C0876418485365FB9 /\* CiteTrack \*/ = \{[^}]+buildPhases = \(([^)]+)\);)'
    match = re.search(target_pattern, content, re.DOTALL)
    
    if not match:
        print("❌ Could not find target buildPhases section")
        return
    
    # Get existing build phases
    existing_phases = match.group(2).strip()
    
    # Add the new script phase UUID to the buildPhases list (after Embed Frameworks)
    embed_frameworks_uuid = "62DE196BA960438E9052558D"
    if embed_frameworks_uuid in existing_phases:
        # Insert after Embed Frameworks
        new_phases = existing_phases.replace(
            f"{embed_frameworks_uuid} /* Embed Frameworks */,",
            f"{embed_frameworks_uuid} /* Embed Frameworks */,\n\t\t\t\t{script_phase_uuid} /* Sign Sparkle Components */,"
        )
    else:
        # Append at the end
        new_phases = existing_phases + f",\n\t\t\t\t{script_phase_uuid} /* Sign Sparkle Components */"
    
    # Replace the buildPhases section
    new_target_section = match.group(0).replace(match.group(2), new_phases)
    content = content.replace(match.group(0), new_target_section)
    
    # Add the PBXShellScriptBuildPhase object before the PBXProject section
    script_phase = f"""
\t\t{script_phase_uuid} /* Sign Sparkle Components */ = {{
\t\t\tisa = PBXShellScriptBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\tinputFileListPaths = (
\t\t\t);
\t\t\tinputPaths = (
\t\t\t);
\t\t\tname = "Sign Sparkle Components";
\t\t\toutputFileListPaths = (
\t\t\t);
\t\t\toutputPaths = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t\tshellPath = /bin/sh;
\t\t\tshellScript = \"\\\"${{SRCROOT}}/scripts/sign_sparkle_components.sh\\\"\\n\";
\t\t}};
"""
    
    # Insert before PBXProject section
    project_pattern = r'(/\* Begin PBXProject section \*/)'
    content = re.sub(project_pattern, script_phase + r'\1', content)
    
    # Write back
    with open(project_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print("✅ Added Sign Sparkle Components build phase")
    print(f"   Script: scripts/sign_sparkle_components.sh")
    print(f"   UUID: {script_phase_uuid}")

if __name__ == "__main__":
    import os
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(os.path.dirname(script_dir))
    project_file = os.path.join(project_root, "macOS", PROJECT_FILE)
    
    if not os.path.exists(project_file):
        print(f"❌ Project file not found: {project_file}")
        sys.exit(1)
    
    add_build_phase_script(project_file)
    print("\n✅ Done! Please open the project in Xcode to verify the new build phase.")

