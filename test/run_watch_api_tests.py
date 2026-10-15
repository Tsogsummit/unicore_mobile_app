"""Compile the production Watch API with isolated networking/keychain fixtures."""
from pathlib import Path
import subprocess
import tempfile
root = Path(__file__).resolve().parents[1]
source = (root / 'ios/unicore-attendancewatch Watch App/ContentView.swift').read_text()
api = source[source.index('@MainActor\nfinal class UnicoreWatchAPI'):]
with tempfile.TemporaryDirectory(prefix='unicore-watch-tests-') as directory:
    generated = Path(directory) / 'tests.swift'
    binary = Path(directory) / 'tests'
    generated.write_text((root / 'test/watch_api_stubs.swift').read_text() + '\n' + api + '\n' + (root / 'test/watch_api_test.swift').read_text())
    subprocess.run(['xcrun', 'swiftc', '-parse-as-library', str(generated), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
