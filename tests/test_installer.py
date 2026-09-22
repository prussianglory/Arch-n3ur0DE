"""Проверки подготовки и записи конфигов. Не устанавливают пакеты/службы.

Запуск из корня репозитория: python3 -m unittest discover -s tests -v
"""
import argparse
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('prepare', REPO / 'installer/prepare.py')
prepare = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prepare)


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='n3ur0de-test-')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.user_dir = self.root / 'user with spaces'
        self.user_dir.mkdir()
        self.config = self.user_dir / '.config'
        self.stage_dir = self.root / 'stage'

    def build(self, profile='desktop', gpu='nvidia', **overrides):
        args = dict(source=REPO, output=self.stage_dir, profile=profile, gpu=gpu,
                    wallpaper=None, user_home=self.user_dir, config_home=self.config,
                    state_home=None)
        args.update(overrides)
        with contextlib.redirect_stdout(io.StringIO()):
            prepare.stage(argparse.Namespace(**args))

    def deploy(self, backup_name='backup'):
        backup = self.user_dir / backup_name
        with contextlib.redirect_stdout(io.StringIO()):
            prepare.deploy(argparse.Namespace(source=self.stage_dir, user_home=self.user_dir,
                                             config_home=self.config, backup=backup))
        return backup, json.loads((backup / 'files.json').read_text())

    def test_missing_zshrc_and_renamed_paths_are_repaired(self):
        self.build()
        for relative in ['.zshenv', '.config/zsh/.zshrc', '.config/hypr/hyprland.lua',
                         '.config/kitty/kitty.conf', '.config/waybar/config.jsonc',
                         '.config/swaync/config.json', '.config/fuzzel/colors.ini',
                         '.config/hypr/hypridle.conf', '.config/hypr/hyprlock.conf']:
            self.assertTrue((self.stage_dir / relative).is_file(), relative)
        self.assertFalse(list(self.stage_dir.rglob('*.md')))
        self.assertFalse(self.config.exists())
        self.assertIn('conf.d/*.zsh', (self.stage_dir / '.config/zsh/.zshrc').read_text())

    def test_profiles_and_lua_integration(self):
        for profile, gpu in [('desktop', 'nvidia'), ('desktop', 'amd'), ('vm', 'none')]:
            output = self.root / (profile + gpu)
            self.build(profile, gpu, output=output)
            hypr = output / '.config/hypr'
            active_env = '\n'.join(l for l in (hypr / 'conf/environment.lua').read_text().splitlines()
                                   if l.startswith('hl.env'))
            self.assertEqual('__GLX_VENDOR_LIBRARY_NAME' in active_env, gpu == 'nvidia')
            entry = (hypr / 'hyprland.lua').read_text()
            self.assertLess(entry.index('require("conf.installer")'), entry.index('require("conf.local")'))
            self.assertEqual('enabled = false' in (hypr / 'conf/installer.lua').read_text(), profile == 'vm')
            waybar = prepare.parse_jsonc((output / '.config/waybar/config.jsonc').read_text())
            self.assertEqual('custom/gpu' in waybar['modules-right'], gpu == 'nvidia')
            self.assertIn('hyprland/language', waybar['modules-right'])
            self.assertEqual(waybar['hyprland/language']['format'], '{}')
            self.assertIn('ext/workspaces', waybar['modules-left'])
            self.assertNotIn('hyprland/workspaces', waybar)
            self.assertEqual(waybar['ext/workspaces']['on-click'], 'activate')
            self.assertIn('hl.dsp.focus', waybar['ext/workspaces']['on-scroll-up'])
            self.assertIn('lock-now.sh', (hypr / 'scripts/session-action.sh').read_text())
            self.assertIn(' --direct', (hypr / 'hypridle.conf').read_text())
            self.assertIn('inhibit_sleep = 3', (hypr / 'hypridle.conf').read_text())

    def test_jsonc_keeps_urls_strings_and_trailing_commas(self):
        result = prepare.parse_jsonc('''{// comment
          "url": "https://host/path", /* block */ "literal": ",]", "list": [1,],
        }''')
        self.assertEqual(result, {'url': 'https://host/path', 'literal': ',]', 'list': [1]})
        self.assertEqual(prepare.parse_jsonc(prepare.waybar_text(result)), result)

    def test_bad_source_fails_before_deployment(self):
        with self.assertRaises(ValueError):
            self.build(source=self.root / 'missing')
        self.assertFalse(self.config.exists())

    def test_deploy_backs_up_files_preserves_links_and_is_repeatable(self):
        self.build()
        kitty = self.config / 'kitty/kitty.conf'
        kitty.parent.mkdir(parents=True)
        kitty.write_text('old kitty\n')
        outside = self.root / 'external-starship'
        outside.write_text('external content\n')
        (self.config / 'starship.toml').symlink_to(outside)
        local = self.config / 'hypr/conf/local.lua'
        local.parent.mkdir(parents=True)
        local.write_text('-- personal override\n')
        backup, receipt = self.deploy()
        self.assertEqual((backup / 'home/.config/kitty/kitty.conf').read_text(), 'old kitty\n')
        self.assertTrue((backup / 'home/.config/starship.toml').is_symlink())
        self.assertFalse((self.config / 'starship.toml').is_symlink())
        self.assertEqual(outside.read_text(), 'external content\n')
        self.assertEqual(local.read_text(), '-- personal override\n')
        self.assertGreater(len(receipt), 40)
        _, second = self.deploy('backup-second')
        self.assertEqual(second, [])
        with self.assertRaises(ValueError):
            self.deploy()

    def test_linked_directory_rejected_before_any_writes(self):
        self.build()
        elsewhere = self.root / 'other'
        elsewhere.mkdir()
        self.config.mkdir()
        (self.config / 'zsh').symlink_to(elsewhere, target_is_directory=True)
        with self.assertRaises(ValueError):
            self.deploy()
        self.assertFalse((self.config / 'hypr').exists())
        self.assertFalse((self.user_dir / '.zshenv').exists())
        self.assertEqual(list(elsewhere.iterdir()), [])

    def test_dotdot_cannot_escape_home(self):
        self.build()
        self.config = self.user_dir / '../outside-config'
        with self.assertRaises(ValueError):
            self.deploy()
        self.assertFalse((self.root / 'outside-config').exists())

    def test_gpu_metrics_valid_json_for_missing_unavailable_and_valid_gpu(self):
        self.build()
        script = self.stage_dir / '.config/waybar/scripts/gpu-nvidia.py'
        fake_bin = self.root / 'bin'
        fake_bin.mkdir()
        executable = fake_bin / 'nvidia-smi'
        env = dict(os.environ, PATH=str(fake_bin) + ':' + os.environ['PATH'])
        python = shutil.which('python3')
        for body, expected in [('exit 1', 0),
                               ("printf '%s\\n' 'RTX 5060, N/A, N/A, 8192, N/A, N/A'", 0),
                               ("printf '%s\\n' 'RTX 5060, 42, 1000, 8192, 60, 95'", 42)]:
            executable.write_text('#!/bin/sh\n' + body + '\n')
            executable.chmod(0o755)
            result = subprocess.run([python, str(script)], env=env, check=True, capture_output=True, text=True)
            self.assertEqual(json.loads(result.stdout)['percentage'], expected)

    def test_shell_syntax(self):
        self.build()
        subprocess.run(['bash', '-n', str(REPO / 'install.sh')], check=True)
        for file in self.stage_dir.rglob('*.sh'):
            subprocess.run(['bash', '-n', str(file)], check=True)
        if shutil.which('zsh'):
            files = list(self.stage_dir.rglob('*.zsh'))
            files += [self.stage_dir / '.zshenv', self.stage_dir / '.config/zsh/.zshrc']
            for file in files:
                subprocess.run(['zsh', '-n', str(file)], check=True)

    def test_cli_dry_run_and_guest_package_plans(self):
        for vm, package in [('virtualbox', 'virtualbox-guest-utils'), ('kvm', 'qemu-guest-agent'),
                            ('vmware', 'open-vm-tools'), ('generic', 'mesa')]:
            result = subprocess.run(['bash', str(REPO / 'install.sh'), '--profile', 'vm',
                                     '--vm-type', vm, '--source', str(REPO), '--dry-run',
                                     '--display-manager', 'none', '--no-apps'],
                                    capture_output=True, text=True, check=True)
            packages = result.stdout.split('Пакеты:\n', 1)[1].split('\n', 1)[0].split()
            self.assertIn(package, packages)
            self.assertNotIn('nvidia-open-dkms', packages)
            self.assertNotIn('sddm', packages)
            self.assertNotIn('firefox', packages)
        self.assertFalse(self.config.exists())


if __name__ == '__main__':
    unittest.main()
