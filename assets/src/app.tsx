import 'phoenix_html';

import { lazy } from 'react';
import { createInertiaApp } from '@inertiajs/react';
import { createRoot } from 'react-dom/client';

import axios from 'axios';

import { Leads } from './pages/Leads/Leads';
import { Signin } from './pages/Signin';
import { Welcome } from './pages/Welcome';

const LazyDocument = lazy(() => import('./pages/Document/Document'));

axios.defaults.xsrfHeaderName = 'x-csrf-token';

const pages = {
  Leads,
  Signin,
  Welcome,
  Document: LazyDocument,
};
createInertiaApp({
  resolve: async name => {
    return await pages[name as keyof typeof pages];
  },
  setup({ App, el, props }) {
    createRoot(el).render(<App {...props} />);
  },
});
