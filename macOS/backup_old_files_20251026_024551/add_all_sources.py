#!/usr/bin/env python3
"""
自动将所有源文件添加到 CiteTrack_macOS.xcodeproj
"""

import os
import uuid
from pathlib import Path

def gen_id():
    """生成 24 位 Xcode ID"""
    return uuid.uuid4().hex[:24].upper()

# 读取现有的项目文件
with open("CiteTrack_macOS.xcodeproj/project.pbxproj", 'r') as f:
    content = f.read()

# 获取所有源文件（排除已添加的）
all_sources = sorted([f.name for f in Path("Sources").glob("*.swift")])
existing_sources = ['main.swift', 'Localization.swift']
new_sources = [f for f in all_sources if f not in existing_sources]

print(f"找到 {len(new_sources)} 个需要添加的源文件")

# 为每个新文件生成 ID
file_data = {}
for fname in new_sources:
    file_data[fname] = {
        'file_ref': gen_id(),
        'build_ref': gen_id()
    }

# 生成 CoreData 模型的 ID
coredata_ref = gen_id()
coredata_build = gen_id()

# 构建新的 PBXBuildFile 部分
new_build_files = ""
for fname, ids in file_data.items():
    new_build_files += f"\t\t{ids['build_ref']} /* {fname} in Sources */ = {{isa = PBXBuildFile; fileRef = {ids['file_ref']} /* {fname} */; }};\n"
new_build_files += f"\t\t{coredata_build} /* CitationTrackingModel.xcdatamodeld in Sources */ = {{isa = PBXBuildFile; fileRef = {coredata_ref} /* CitationTrackingModel.xcdatamodeld */; }};\n"

# 构建新的 PBXFileReference 部分
new_file_refs = ""
for fname, ids in file_data.items():
    new_file_refs += f"\t\t{ids['file_ref']} /* {fname} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {fname}; sourceTree = \"<group>\"; }};\n"
new_file_refs += f"\t\t{coredata_ref} /* CitationTrackingModel.xcdatamodeld */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.xcdatamodeld; path = CitationTrackingModel.xcdatamodeld; sourceTree = \"<group>\"; }};\n"

# 构建新的 Sources 组子项
new_group_children = ""
for fname, ids in file_data.items():
    new_group_children += f"\t\t\t\t{ids['file_ref']} /* {fname} */,\n"
new_group_children += f"\t\t\t\t{coredata_ref} /* CitationTrackingModel.xcdatamodeld */,\n"

# 构建新的 Sources build phase files
new_sources_files = ""
for fname, ids in file_data.items():
    new_sources_files += f"\t\t\t\t{ids['build_ref']} /* {fname} in Sources */,\n"
new_sources_files += f"\t\t\t\t{coredata_build} /* CitationTrackingModel.xcdatamodeld in Sources */,\n"

# 插入新的 PBXBuildFile
content = content.replace(
    "\t\tA1000004 /* Sparkle.framework in Embed Frameworks */ = {isa = PBXBuildFile; fileRef = B1000003 /* Sparkle.framework */; settings = {ATTRIBUTES = (CodeSignOnCopy, RemoveHeadersOnCopy, ); }; };\n/* End PBXBuildFile section */",
    f"\t\tA1000004 /* Sparkle.framework in Embed Frameworks */ = {{isa = PBXBuildFile; fileRef = B1000003 /* Sparkle.framework */; settings = {{ATTRIBUTES = (CodeSignOnCopy, RemoveHeadersOnCopy, ); }}; }};\n{new_build_files}/* End PBXBuildFile section */"
)

# 插入新的 PBXFileReference
content = content.replace(
    "\t\tD1000001 /* CiteTrack.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = CiteTrack.app; sourceTree = BUILT_PRODUCTS_DIR; };\n/* End PBXFileReference section */",
    f"\t\tD1000001 /* CiteTrack.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = CiteTrack.app; sourceTree = BUILT_PRODUCTS_DIR; }};\n{new_file_refs}/* End PBXFileReference section */"
)

# 更新 Sources 组
content = content.replace(
    "\t\t\tchildren = (\n\t\t\t\tB1000001 /* main.swift */,\n\t\t\t\tB1000002 /* Localization.swift */,\n\t\t\t);",
    f"\t\t\tchildren = (\n\t\t\t\tB1000001 /* main.swift */,\n\t\t\t\tB1000002 /* Localization.swift */,\n{new_group_children}\t\t\t);"
)

# 更新 Sources build phase
content = content.replace(
    "\t\t\tfiles = (\n\t\t\t\tA1000001 /* main.swift in Sources */,\n\t\t\t\tA1000002 /* Localization.swift in Sources */,\n\t\t\t);",
    f"\t\t\tfiles = (\n\t\t\t\tA1000001 /* main.swift in Sources */,\n\t\t\t\tA1000002 /* Localization.swift in Sources */,\n{new_sources_files}\t\t\t);"
)

# 写回项目文件
with open("CiteTrack_macOS.xcodeproj/project.pbxproj", 'w') as f:
    f.write(content)

print(f"✅ 已添加 {len(new_sources)} 个源文件")
print(f"✅ 已添加 CoreData 模型")
print("\n添加的文件:")
for fname in new_sources:
    print(f"  • {fname}")
print(f"  • CitationTrackingModel.xcdatamodeld")

