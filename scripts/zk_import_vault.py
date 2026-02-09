#!/usr/bin/env python3
import argparse
import base64
import json
import subprocess
import sys
from typing import Any, Dict, Iterable, List, Optional, Tuple

def iter_nodes(root: Any) -> Iterable[Dict[str, Any]]:
    """
    Yield nodes in ZK export format:
    node = {"h": {"path": "...", "data": "...", ...}, "t": [child_nodes...]}
    Root can be a list of nodes or a single node.
    """
    stack: List[Any] = []
    stack.append(root)

    while stack:
        cur = stack.pop()
        if cur is None:
            continue
        if isinstance(cur, list):
            # push items reversed to keep natural order (not required)
            for x in reversed(cur):
                stack.append(x)
            continue
        if isinstance(cur, dict):
            # if it looks like a node, yield it
            if "h" in cur and isinstance(cur.get("h"), dict):
                yield cur
                children = cur.get("t")
                if isinstance(children, list) and children:
                    for ch in reversed(children):
                        stack.append(ch)
            else:
                # sometimes dumps can wrap nodes under other keys; traverse dict values
                for v in cur.values():
                    stack.append(v)

def normalize_path(zk_path: str) -> str:
    if not zk_path:
        return "/"
    if not zk_path.startswith("/"):
        zk_path = "/" + zk_path
    # remove duplicate slashes
    while "//" in zk_path:
        zk_path = zk_path.replace("//", "/")
    # strip trailing slash except root
    if zk_path != "/" and zk_path.endswith("/"):
        zk_path = zk_path[:-1]
    return zk_path

def looks_like_base64(s: str) -> bool:
    # Quick heuristic: base64 is usually ascii, length multiple of 4, only valid chars and '=' padding.
    if not s or not isinstance(s, str):
        return False
    if len(s) % 4 != 0:
        return False
    # allow empty string already handled
    allowed = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=\n\r"
    return all(c in allowed for c in s)

def is_valid_base64(s: str) -> bool:
    if not looks_like_base64(s):
        return False
    try:
        base64.b64decode(s, validate=True)
        return True
    except Exception:
        return False

def vault_kv_put(vault_path: str, kv: Dict[str, str], dry_run: bool = False) -> None:
    cmd = ["vault", "kv", "put", vault_path] + [f"{k}={v}" for k, v in kv.items()]
    if dry_run:
        print("DRY-RUN:", " ".join(cmd))
        return
    subprocess.check_call(cmd)

def main() -> int:
    ap = argparse.ArgumentParser(
        description="Import ZooKeeper JSON tree export (h/t) into HashiCorp Vault KV."
    )
    ap.add_argument("input_json", help="Path to ZK JSON export file")
    ap.add_argument("--prefix", default="secret/zk", help="Vault KV path prefix (default: secret/zk)")
    ap.add_argument("--include-empty", action="store_true",
                    help="Also write empty nodes (data=='' or missing) as empty=true")
    ap.add_argument("--skip-empty", action="store_true",
                    help="Skip nodes with empty data (overrides --include-empty)")
    ap.add_argument("--dry-run", action="store_true", help="Print vault commands without executing")
    ap.add_argument("--max", type=int, default=0, help="Limit number of writes (0 = no limit)")
    ap.add_argument("--value-key", default="value", help="Key name for plain values (default: value)")
    ap.add_argument("--b64-key", default="value_b64", help="Key name for base64 values (default: value_b64)")
    args = ap.parse_args()

    with open(args.input_json, "r", encoding="utf-8") as f:
        root = json.load(f)

    prefix = args.prefix.rstrip("/")
    writes = 0
    seen_paths = set()

    for node in iter_nodes(root):
        h = node.get("h") or {}
        zk_path_raw = h.get("path")
        if not isinstance(zk_path_raw, str) or not zk_path_raw:
            continue

        zk_path = normalize_path(zk_path_raw)
        # protect against duplicates
        if zk_path in seen_paths:
            continue
        seen_paths.add(zk_path)

        vault_path = f"{prefix}{zk_path}"  # prefix + /a/b/c => secret/zk/a/b/c

        data = h.get("data", "")
        if data is None:
            data = ""
        if not isinstance(data, str):
            # if data is not a string, store JSON string representation
            data = json.dumps(data, ensure_ascii=False)

        if data == "":
            if args.skip_empty:
                continue
            if args.include_empty:
                vault_kv_put(vault_path, {"empty": "true"}, dry_run=args.dry_run)
                writes += 1
        else:
            if is_valid_base64(data):
                vault_kv_put(vault_path, {args.b64_key: data}, dry_run=args.dry_run)
                writes += 1
            else:
                vault_kv_put(vault_path, {args.value_key: data}, dry_run=args.dry_run)
                writes += 1

        if args.max and writes >= args.max:
            break

    print(f"Done. Unique nodes seen: {len(seen_paths)}; writes: {writes}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
