/* eslint no-console: off */
const isCI = require('is-ci');
const { copyFileSync, chmod } = require('fs');
const path = require('path');

if (!isCI) {
  console.log('Setting up pre-commit hook');

  const rootDir = path.join(process.cwd(), '..');
  const sourcePath = path.join(rootDir, '.github', 'hooks', 'pre-commit');
  const targetPath = path.join(rootDir, '.git', 'hooks', 'pre-commit');

  copyFileSync(sourcePath, targetPath);

  console.log('pre-commit installed successfully');

  chmod(targetPath, 0o755, err => {
    if (err) throw err;
    console.log('permissions for pre-commit have changed successfully!');
  });
} else {
  console.log('CI env detected. Skipping setup of pre-commit-hook');
}
