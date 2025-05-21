import "phoenix_html";

import React from "react";
import { createInertiaApp } from "@inertiajs/react";
import { createRoot } from "react-dom/client";
import axios from "axios";

axios.defaults.xsrfHeaderName = "x-csrf-token";

createInertiaApp({
  resolve: async (name) => {
    console.log(name);
    const module = await import(`./pages/DemoPageOne.jsx`);
    return module;
  },
  setup({ App, el, props }) {
    createRoot(el).render(<App {...props} />);
  },
});
