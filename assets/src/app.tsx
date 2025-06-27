import { lazy } from 'react';
import { createRoot } from 'react-dom/client';
import { createInertiaApp } from '@inertiajs/react';

import axios from 'axios';

import 'phoenix_html';

// Configure axios defaults
axios.defaults.headers.common['X-Requested-With'] = 'XMLHttpRequest';
axios.defaults.withCredentials = true;
axios.defaults.xsrfHeaderName = 'x-csrf-token';

// Lazy load pages
const Signin = lazy(() => import('./pages/Signin/Signin'));
const Welcome = lazy(() => import('./pages/Welcome'));
const Leads = lazy(() => import('./pages/Leads/Leads'));
const Document = lazy(() => import('./pages/Document'));

const pages = {
  Leads,
  Signin,
  Welcome,
  Document,
};

createInertiaApp({
  resolve: name => pages[name as keyof typeof pages],
  setup({ App, el, props }) {
    createRoot(el).render(<App {...props} />);
  },
});
