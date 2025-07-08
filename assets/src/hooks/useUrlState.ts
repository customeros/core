import { useCallback } from 'react';
import { router } from '@inertiajs/react';

interface UrlStateOptions {
  path?: string;
  revalidate?: string[];
}

export const useUrlState = <T extends Record<string, string>>(options?: UrlStateOptions) => {
  const _options = options || {};
  const _path = options?.path || window.location.pathname;

  const getUrlState = () => {
    const params = new URLSearchParams(window.location.search);

    return Object.fromEntries(params.entries()) as T;
  };

  const setUrlState = useCallback(
    (updater: (state: T) => T, options?: { revalidate?: string[] }) => {
      const state = updater(getUrlState());

      const params = new URLSearchParams();

      Object.entries(state).forEach(([key, value]) => {
        params.set(key, value);
      });

      router.get(
        _path,
        {
          ...Object.fromEntries(params.entries()),
        },
        {
          only: options?.revalidate || _options.revalidate || [],
          replace: true,
          preserveState: true,
        }
      );
    },
    []
  );

  return { getUrlState, setUrlState };
};
