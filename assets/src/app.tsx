import { lazy } from 'react';
import { createRoot } from 'react-dom/client';
import { createInertiaApp } from '@inertiajs/react';
import { PostHogProvider } from './providers/PostHogProvider';

import axios from 'axios';

import 'phoenix_html';

const Signin = lazy(() => import('./pages/Signin'));
const Welcome = lazy(() => import('./pages/Welcome'));
const Leads = lazy(() => import('./pages/Leads/Leads'));
const Document = lazy(() => import('./pages/Document'));

axios.defaults.xsrfHeaderName = 'x-csrf-token';

const pages = {
  Leads,
  Signin,
  Welcome,
  Document,
};

createInertiaApp({
  resolve: async name => {
    return await pages[name as keyof typeof pages];
  },
  setup({ App, el, props }) {
    createRoot(el).render(
      <PostHogProvider>
        <App {...props} />
      </PostHogProvider>
    );
  },
});
