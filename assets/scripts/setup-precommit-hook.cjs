/* eslint no-console: off */
const isCI = require('is-ci');
const { writeFileSync, chmod, mkdirSync, symlinkSync } = require('fs');
const path = require('path');

if (!isCI) {
  console.log('Setting up pre-commit hook');

  const hookContent = `#!/bin/bash

echo "Running React lint in assets/..."

# Navigate into the React project
cd assets || exit 1

npx lint

if [ $? -ne 0 ]; then
  echo "❌ Lint failed. Commit aborted."
  exit 1
fi

echo "✅ Lint passed. Continuing with commit."
exit 0`;

  // Get the root directory (one level up from assets)
  const rootDir = path.join(process.cwd(), '..');
  const githubHooksDir = path.join(rootDir, '.github', 'hooks');
  const gitHooksDir = path.join(rootDir, '.git', 'hooks');
  const githubHookPath = path.join(githubHooksDir, 'pre-commit');
  const gitHookPath = path.join(gitHooksDir, 'pre-commit');

  // Ensure the .github/hooks directory exists
  try {
    mkdirSync(githubHooksDir, { recursive: true });
    mkdirSync(gitHooksDir, { recursive: true });
  } catch (err) {
    if (err.code !== 'EEXIST') throw err;
  }

  // Create the hook file in .github/hooks
  writeFileSync(githubHookPath, hookContent);
  console.log('pre-commit hook created at:', githubHookPath);

  // Create symlink in .git/hooks
  try {
    symlinkSync(githubHookPath, gitHookPath);
    console.log('Symlink created from .git/hooks/pre-commit to .github/hooks/pre-commit');
  } catch (err) {
    if (err.code === 'EEXIST') {
      console.log('Symlink already exists');
    } else {
      throw err;
    }
  }

  chmod(githubHookPath, 0o755, err => {
    if (err) throw err;
    console.log('permissions for pre-commit have changed successfully!');
  });
} else {
  console.log('CI env detected. Skipping setup of pre-commit-hook');
}
