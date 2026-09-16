"""Cloud entrypoint: require Supabase; never store tester data on ephemeral disk."""
import os
import runpy
from pathlib import Path

os.environ["NEXUS_BACKEND"] = "supabase"
runpy.run_path(str(Path(__file__).parent / "app" / "app.py"), run_name="__main__")
