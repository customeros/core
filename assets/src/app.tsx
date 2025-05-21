import 'phoenix_html';

import React from 'react';
import { createInertiaApp } from '@inertiajs/react';
import { createRoot } from 'react-dom/client';
import axios from 'axios';

import { DemoPageOne } from './pages/DemoPageOne';
import { ListGroceries } from './pages/ListGroceries';
import { NewGrocery } from './pages/NewGrocery';
import { Leads } from './pages/Leads';

axios.defaults.xsrfHeaderName = 'x-csrf-token';

const pages = {
  DemoPageOne,
  ListGroceries,
  NewGrocery,
  Leads,
};
createInertiaApp({
  resolve: async name => {
    return await pages[name as keyof typeof pages];
  },
  setup({ App, el, props }) {
    createRoot(el).render(<App {...props} />);
  },
});
