#!/usr/bin/env python3
"""Refresh or check exact source excerpts and local links in the RISCue manual."""
import argparse,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
MANUAL=ROOT/'docs/RISCUE_MANUAL.md'
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check',action='store_true');args=p.parse_args()
    text=MANUAL.read_text();updated=text;entries=json.loads((ROOT/'docs/manual-excerpts.json').read_text())
    for entry in entries:
        lines=(ROOT/entry['path']).read_text().splitlines();matches=[i for i,line in enumerate(lines) if entry['start'] in line]
        if len(matches)!=1:raise SystemExit(f"Excerpt {entry['id']}: start anchor must be unique, found {len(matches)}")
        code='\n'.join(lines[matches[0]:matches[0]+entry['lines']]);marker=entry['id']
        replacement=f"<!-- excerpt:{marker} -->\nSource: [{entry['path']}](../{entry['path']})\n\n```{entry['language']}\n{code}\n```\n<!-- /excerpt:{marker} -->"
        pattern=rf'<!-- excerpt:{re.escape(marker)} -->.*?<!-- /excerpt:{re.escape(marker)} -->'
        updated,count=re.subn(pattern,lambda m:replacement,updated,flags=re.S)
        if count!=1:raise SystemExit(f'Excerpt {marker}: expected one marker pair')
    def anchors(markdown):
        clean=re.sub(r'```.*?```','',markdown,flags=re.S);found=set();counts={}
        for title in re.findall(r'^#{1,6} (.+)$',clean,flags=re.M):
            slug=re.sub(r'[^\w -]','',title.lower()).replace(' ','-')
            count=counts.get(slug,0);counts[slug]=count+1;found.add(slug+(f'-{count}' if count else ''))
        return found
    # Local paths in this manual must exist. External links and in-page anchors are separate.
    links=re.findall(r'\]\(([^)]+)\)',updated)
    for target in links:
        if re.match(r'[a-zA-Z]+:',target):continue
        path,separator,anchor=target.partition('#');linked=MANUAL.parent/path if path else MANUAL
        if not linked.exists():raise SystemExit(f'Missing manual link: {target}')
        if separator and linked.suffix=='.md' and anchor not in anchors(updated if linked==MANUAL else linked.read_text()):
            raise SystemExit(f'Missing heading anchor: {target}')
    if args.check and text!=updated:raise SystemExit('Manual excerpts are stale; run make docs')
    if not args.check:MANUAL.write_text(updated)
    print(f'PASS: {len(entries)} source excerpts synchronized; {len(links)} manual links checked')
if __name__=='__main__':main()
