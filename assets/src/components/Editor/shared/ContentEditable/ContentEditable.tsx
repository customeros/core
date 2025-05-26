import { ContentEditable } from '@lexical/react/LexicalContentEditable';

import './ContentEditable.css';

export default function LexicalContentEditable({
  className,
}: {
  className?: string;
}): React.ReactNode {
  return <ContentEditable className={className || 'ContentEditable__root'} />;
}
