/* eslint-disable @typescript-eslint/no-explicit-any */
import { usePage } from '@inertiajs/react';
import { useEffect, useContext, createContext, type ReactNode } from 'react';

interface AtlasContextType {
  identify: (user: { name?: string; userId: string; email?: string }) => void;
}

interface SupportProps {
  atlasAppId: string;
}

interface UserProps {
  email: string;
}

const AtlasContext = createContext<AtlasContextType | null>(null);

export const useAtlas = () => {
  const context = useContext(AtlasContext);

  if (!context) {
    throw new Error('useAtlas must be used within an AtlasProvider');
  }

  return context;
};

interface AtlasProviderProps {
  children: ReactNode;
}

export const AtlasProvider = ({ children }: AtlasProviderProps) => {
  const { props } = usePage();
  const support = props.support as SupportProps | undefined;
  const user = props.user as UserProps | undefined;

  useEffect(() => {
    let script: HTMLScriptElement | null = null;

    const initializeAtlas = () => {
      if (!support?.atlasAppId) {
        console.warn('Atlas app ID is not defined. Support will be disabled.');

        return;
      }

      try {
        // Initialize Atlas
        const atlasInstance = {
          appId: support.atlasAppId,
          v: 2,
          q: [] as any[],
          call: function (...args: any[]) {
            this.q.push(args);
          },
        };

        (window as any).Atlas = atlasInstance;

        script = document.createElement('script');
        script.async = true;
        script.src = 'https://app.atlas.so/client-js/atlas.bundle.js';

        script.onerror = error => {
          console.error('Failed to load Atlas script:', error);
        };

        script.onload = () => {
          try {
            // Start Atlas
            (window as any).Atlas.call('start');

            // Identify user if available
            if (user?.email) {
              (window as any).Atlas.call('identify', {
                userId: user.email,
              });
            }
          } catch (error) {
            console.error('Error in Atlas script onload handler:', error);
          }
        };

        document.head.appendChild(script);
      } catch (error) {
        console.error('Error initializing Atlas:', error);
      }
    };

    initializeAtlas();

    return () => {
      if (script && script.parentNode) {
        script.parentNode.removeChild(script);
      }
    };
  }, [support, user]);

  const identify = (user: { name?: string; userId: string; email?: string }) => {
    try {
      if (!(window as any).Atlas) {
        console.warn('Atlas is not initialized. Cannot identify user.');

        return;
      }
      (window as any).Atlas.call('identify', user);
    } catch (error) {
      console.error('Error identifying user in Atlas:', error);
    }
  };

  return <AtlasContext.Provider value={{ identify }}>{children}</AtlasContext.Provider>;
};
