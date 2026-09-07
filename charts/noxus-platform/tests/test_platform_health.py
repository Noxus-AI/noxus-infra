"""Render the chart to check optional-service health defaults and overrides."""

import json
import os
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


CHART = Path(__file__).resolve().parents[1]
HELM = os.environ.get("HELM", "helm")


class PlatformHealthDefaultsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Render the production env templates without fetching unrelated KEDA
        # dependencies. CI separately lints and renders the complete chart.
        cls.directory = tempfile.TemporaryDirectory()
        cls.addClassCleanup(cls.directory.cleanup)
        cls.chart = Path(cls.directory.name)
        (cls.chart / "templates").mkdir()
        (cls.chart / "Chart.yaml").write_text(
            "apiVersion: v2\nname: noxus-platform\nversion: 0.0.0\n"
        )
        shutil.copyfile(CHART / "values.yaml", cls.chart / "values.yaml")
        for name in ("_helpers.tpl", "secrets.yaml"):
            shutil.copyfile(CHART / "templates" / name, cls.chart / "templates" / name)

    def assert_health_flags(self, values, relay, sandbox):
        with tempfile.TemporaryDirectory() as directory:
            overrides = Path(directory) / "values.json"
            overrides.write_text(json.dumps(values))
            result = subprocess.run(
                [
                    HELM,
                    "template",
                    "health-test",
                    str(self.chart),
                    "-f",
                    str(CHART / "ci/minimal-values.yaml"),
                    "-f",
                    str(overrides),
                    "--show-only",
                    "templates/secrets.yaml",
                ],
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            rendered = result.stdout

        # The app, frontend and relay secrets share the same resolved defaults.
        for service, expected in (("RELAY", relay), ("SANDBOX", sandbox)):
            flags = re.findall(
                rf'^  PLATFORM_HEALTH_{service}_ENABLED: "(true|false)"$',
                rendered,
                re.MULTILINE,
            )
            self.assertEqual(flags, [str(expected).lower()] * 3)

    def test_defaults_follow_the_deployed_services(self):
        for relay in (False, True):
            for sandbox in (False, True):
                with self.subTest(relay=relay, sandbox=sandbox):
                    self.assert_health_flags(
                        {"relay": {"enabled": relay}, "sandbox": {"enabled": sandbox}},
                        relay=relay,
                        sandbox=sandbox,
                    )

    def test_external_sandbox_is_expected(self):
        for source in ("env", "extraEnv", "secrets"):
            with self.subTest(source=source):
                self.assert_health_flags(
                    {source: {"SANDBOX_MANAGER_URL": "https://sandbox.example.com"}},
                    relay=False,
                    sandbox=True,
                )

    def test_empty_external_sandbox_is_absent(self):
        self.assert_health_flags(
            {"env": {"SANDBOX_MANAGER_URL": ""}}, relay=False, sandbox=False
        )

    def test_explicit_flags_override_the_topology(self):
        for source in ("env", "extraEnv", "secrets"):
            for enabled in (False, True):
                for flag in (enabled, str(enabled).lower()):
                    with self.subTest(source=source, flag=flag):
                        self.assert_health_flags(
                            {
                                "relay": {"enabled": not enabled},
                                "sandbox": {"enabled": not enabled},
                                source: {
                                    "PLATFORM_HEALTH_RELAY_ENABLED": flag,
                                    "PLATFORM_HEALTH_SANDBOX_ENABLED": flag,
                                },
                            },
                            relay=enabled,
                            sandbox=enabled,
                        )

    def test_explicit_flags_follow_env_source_precedence(self):
        for lower, higher in (
            ("env", "extraEnv"),
            ("env", "secrets"),
            ("extraEnv", "secrets"),
        ):
            for enabled in (False, True):
                for flag in (enabled, str(enabled).lower()):
                    with self.subTest(lower=lower, higher=higher, flag=flag):
                        self.assert_health_flags(
                            {
                                lower: {
                                    "PLATFORM_HEALTH_RELAY_ENABLED": not enabled,
                                    "PLATFORM_HEALTH_SANDBOX_ENABLED": not enabled,
                                },
                                higher: {
                                    "PLATFORM_HEALTH_RELAY_ENABLED": flag,
                                    "PLATFORM_HEALTH_SANDBOX_ENABLED": flag,
                                },
                            },
                            relay=enabled,
                            sandbox=enabled,
                        )


if __name__ == "__main__":
    unittest.main()
