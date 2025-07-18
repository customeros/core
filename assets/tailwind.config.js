// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

const plugin = require('tailwindcss/plugin');
const fs = require('fs');
const path = require('path');

module.exports = {
  content: ['./js/**/*.js', './js/**/*.jsx', '../lib/web/**/*.*ex'],
  theme: {
    extend: {
      colors: {
        brand: '#FD4F00',
      },
    },
    fontFamily: {
      heading: ['IBM Plex Sans'],
      body: ['IBM Plex Sans'],
    },
    borderColor: {
      transparent: 'transparent',
    },
    extends: {
      flex: {
        2: '2 2 0%',
        3: '3 3 0%',
        4: '4 4 0%',
        5: '5 5 0%',
        6: '6 6 0%',
        7: '7 7 0%',
        8: '8 8 0%',
        9: '9 9 0%',
      },
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    // Allows prefixing tailwind classes with LiveView classes to add rules
    // only when LiveView classes are applied, for example:
    //
    //     <div class="phx-click-loading:animate-ping">
    //
    plugin(({ addVariant }) =>
      addVariant('phx-no-feedback', ['.phx-no-feedback&', '.phx-no-feedback &'])
    ),
    plugin(({ addVariant }) =>
      addVariant('phx-click-loading', ['.phx-click-loading&', '.phx-click-loading &'])
    ),
    plugin(({ addVariant }) =>
      addVariant('phx-submit-loading', ['.phx-submit-loading&', '.phx-submit-loading &'])
    ),
    plugin(({ addVariant }) =>
      addVariant('phx-change-loading', ['.phx-change-loading&', '.phx-change-loading &'])
    ),
  ],
};
