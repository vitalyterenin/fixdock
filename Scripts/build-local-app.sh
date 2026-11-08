#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash Scripts/build-app.sh >/dev/null
keychain="$(bash Scripts/setup-signing.sh)"
export FIXDOCK_CODE_SIGN_KEYCHAIN="$keychain"
python3 - <<'PYLOCAL'
import os,subprocess,sys
from pathlib import Path
sys.path.insert(0,'Scripts')
from signing import components
app=Path(os.environ.get('FIXDOCK_OUTPUT_DIR',str(Path.home()/'Library/Developer/Fixdock')))/'Fixdock.app'
keychain=os.environ['FIXDOCK_CODE_SIGN_KEYCHAIN']
identity=os.environ.get('FIXDOCK_CODE_SIGN_IDENTITY','Fixdock Local Code Signing')
output=subprocess.check_output(['security','find-certificate','-c',identity,'-Z',keychain],text=True)
fingerprint=next(line.split(':',1)[1].strip() for line in output.splitlines() if line.startswith('SHA-1 hash:'))
for code in components(app):
 subprocess.run(['codesign','--force','--sign',fingerprint,'--keychain',keychain,'--timestamp=none',str(code)],check=True)
subprocess.run(['codesign','--verify','--deep','--strict',str(app)],check=True)
print(app)
PYLOCAL
