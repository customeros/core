import 'phoenix_html';

import React from 'react';
import { createInertiaApp } from '@inertiajs/react';
import { createRoot } from 'react-dom/client';
import axios from 'axios';

import { DemoPageOne } from './pages/DemoPageOne.js';
import { ListGroceries } from './pages/ListGroceries.jsx';
import { NewGrocery } from './pages/NewGrocery.jsx';

axios.defaults.xsrfHeaderName = 'x-csrf-token';
const pages = {
  DemoPageOne,
  ListGroceries,
  NewGrocery,
};
createInertiaApp({
  resolve: async name => {
    return await pages[name as keyof typeof pages];
  },
  setup({ App, el, props }) {
    createRoot(el).render(<App {...props} />);
  },
});
