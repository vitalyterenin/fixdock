#!/usr/bin/env python3
"""Check signing setup without touching real credentials or keychains."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent


def check(existing):
    with tempfile.TemporaryDirectory(prefix="fixdock-signing-test-") as tmp:
        base = Path(tmp)
        binary_dir = base / "bin"
        binary_dir.mkdir()
        signing_dir = base / "signing directory with spaces"
        signing_dir.mkdir()
        keychain = signing_dir / "fixdock-code-signing.keychain-db"
        for name in ("fixdock-local-code-signing.key.pem",
                     "fixdock-local-code-signing.cert.pem"):
            (signing_dir / name).touch()
        if existing:
            keychain.touch()
        mock = binary_dir / "security"
        mock.write_text('''#!/usr/bin/env bash
printf '%s\\n' "$1" >> "$SIGNING_TEST_CALLS"
case "$1" in
  create-keychain) touch "$4" ;;
  unlock-keychain|set-keychain-settings|find-certificate) exit 0 ;;
  *) echo "Unexpected security operation: $1" >&2; exit 91 ;;
esac
''')
        mock.chmod(0o700)
        env = dict(os.environ, PATH=str(binary_dir) + ":" + os.environ["PATH"],
                   FIXDOCK_SIGNING_DIR=str(signing_dir),
                   SIGNING_TEST_CALLS=str(base / "calls"))
        for _ in range(2):
            result = subprocess.run(["bash", str(ROOT / "Scripts/setup-signing.sh")],
                                    env=env, capture_output=True, text=True)
            assert result.returncode == 0, result.stderr
            assert result.stdout.strip() == str(keychain), result.stdout
        calls = (base / "calls").read_text().splitlines()
        assert calls.count("create-keychain") == (0 if existing else 1), calls
        assert set(calls) <= {"create-keychain", "unlock-keychain",
                              "set-keychain-settings", "find-certificate"}, calls


if __name__ == "__main__":
    check(existing=True)
    check(existing=False)
    print("PASS: repeat setup reuses the keychain; no search-list operations")
