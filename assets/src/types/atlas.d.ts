interface AtlasUser {
  userId: string;
  name?: string;
  email?: string;
}

interface AtlasInstance {
  appId: string;
  v: number;
  q: any[];
  call: (...args: any[]) => void;
}

interface Atlas {
  call: (method: string, ...args: any[]) => void;
}

declare global {
  interface Window {
    Atlas: AtlasInstance;
  }
} 