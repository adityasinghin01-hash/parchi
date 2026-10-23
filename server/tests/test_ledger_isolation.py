"""The test suite must never leave anything in the real reader spend ledger (it would block the real reader with 'cap reached')."""
from pathlib import Path

import reader_claude as rc


def test_tests_use_a_temporary_ledger_and_start_at_zero():
    real = Path(rc.__file__).resolve().parent / "data" / "reader_spend.json"
    assert rc.SPEND_FILE != real, "the autouse fixture must redirect the ledger"
    assert rc.USAGE.lifetime_usd == 0.0
    rc.USAGE.add("claude-opus-5-5", 50_000_000, 0)   # $200 of fake usage in a test that forgot to fake the client
    assert rc.SPEND_FILE.parent != real.parent, "fake usage can only land in the temporary ledger"
