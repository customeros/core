import 'phoenix_html';

import React from 'react';
import { createInertiaApp } from '@inertiajs/react';
import { createRoot } from 'react-dom/client';
import axios from 'axios';

import { Leads } from './pages/Leads';
import { Signin } from './pages/Signin';
axios.defaults.xsrfHeaderName = 'x-csrf-token';

const pages = {
  Leads,
  Signin,
};
createInertiaApp({
  resolve: async name => {
    return await pages[name as keyof typeof pages];
  },
  setup({ App, el, props }) {
    createRoot(el).render(<App {...props} />);
  },
});
