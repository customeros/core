import posthog from 'posthog-js';
import { createContext, useContext, useEffect, type ReactNode } from 'react';

// Initialize PostHog
posthog.init(process.env.POSTHOG_KEY || '', {
  api_host: process.env.POSTHOG_HOST || 'https://app.posthog.com',
  defaults: '2025-05-24',
  person_profiles: 'identified_only',
  loaded: (posthog) => {
    if (process.env.NODE_ENV === 'development') posthog.debug();
  },
});

// Create context
const PostHogContext = createContext<typeof posthog | null>(null);

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
  useEffect(() => {
    // Cleanup on unmount
    return () => {
      posthog.opt_out_capturing();
    };
  }, []);

  return (
    <PostHogContext.Provider value={posthog}>
      {children}
    </PostHogContext.Provider>
  );
}; 