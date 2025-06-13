module.exports = {
  '*.{js,jsx,ts,tsx}': files => {
    const filteredFiles = files.filter(file => !file.includes('.lintstagedrc.js'));
    return filteredFiles.length ? ['eslint'] : [];
  },
};
