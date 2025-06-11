import { usePage } from '@inertiajs/react';
import { useEffect, useContext, createContext, type ReactNode } from 'react';
/* eslint-disable @typescript-eslint/no-explicit-any */

import posthog from 'posthog-js';

interface PostHogContextType {
  capture: (event: string, properties?: Record<string, any>) => void;
}

const PostHogContext = createContext<PostHogContextType | null>(null);

export const usePostHog = () => {
  const context = useContext(PostHogContext);

  if (!context) {
    throw new Error('usePostHog must be used within a PostHogProvider');
  }

  return context;
};

interface PostHogProviderProps {
  children: ReactNode;
}

export const PostHogProvider = ({ children }: PostHogProviderProps) => {
  const { props } = usePage();
  const analytics = props.analytics as { posthogKey: string; posthogHost: string } | undefined;
  const user = props.user as { email: string } | undefined;

  useEffect(() => {
    try {
      if (!analytics?.posthogKey) {
        console.warn('PostHog key is not defined. Analytics will be disabled.');

        return;
      }

      // Initialize PostHog
      posthog.init(analytics.posthogKey, {
        api_host: analytics.posthogHost || 'https://app.posthog.com',
        defaults: '2025-05-24',
        person_profiles: 'identified_only',
        debug: process.env.NODE_ENV === 'development',
        loaded: posthog => {
          if (process.env.NODE_ENV === 'development') posthog.debug();
        },
      });

      // Identify user if available
      if (user?.email) {
        posthog.identify(user.email, {
          email: user.email,
        });
      }
    } catch (error) {
      console.error('Error initializing PostHog:', error);
    }

    return () => {
      posthog.opt_out_capturing();
    };
  }, [analytics, user]);

  const capture = (event: string, properties?: Record<string, any>) => {
    try {
      posthog.capture(event, properties);
    } catch (error) {
      console.error('Error capturing PostHog event:', error);
    }
  };

  return <PostHogContext.Provider value={{ capture }}>{children}</PostHogContext.Provider>;
};
