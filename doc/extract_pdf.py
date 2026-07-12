"""
提取tas6424e-q1 datasheet文本
"""
import pymupdf
import json
import sys

pdf_path = r"K:\ICProject\project_ai_demo\gl006\doc\tas6424e-q1_260708_092629.pdf"

try:
    doc = pymupdf.open(pdf_path)
    print(f"PDF总页数: {doc.page_count}")
    print("=" * 80)

    all_text = []
    for i, page in enumerate(doc):
        text = page.get_text()
        all_text.append(f"=== Page {i+1} ===\n{text}")

    full_text = "\n".join(all_text)

    # 保存为utf-8
    with open(r"K:\ICProject\project_ai_demo\gl006\doc\datasheet_text.md", "w", encoding="utf-8") as f:
        f.write(full_text)

    print(f"已保存 {len(full_text)} 字符到 datasheet_text.md")
    print("\n前500字符预览:")
    print(full_text[:500])

except Exception as e:
    print(f"Error: {e}")
