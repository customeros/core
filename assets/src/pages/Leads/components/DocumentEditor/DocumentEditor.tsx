import { Icon } from 'src/components/Icon/Icon';
import { Editor } from 'src/components/Editor/Editor';
import { FeaturedIcon } from 'src/components/FeaturedIcon/FeaturedIcon';

interface DocumentEditorProps {
  docId: string;
  userId: string;
  presenceUser: {
    username: string;
    cursorColor: string;
  };
}

export const DocumentEditor = ({ docId, presenceUser, userId }: DocumentEditorProps) => {
  if (!docId)
    return (
      <div className="flex items-center justify-start flex-col h-full">
        <div className="flex items-center justify-center">
          <FeaturedIcon className="mb-6 mt-[40px]">
            <Icon name="clock-fast-forward" />
          </FeaturedIcon>
        </div>
        <div className="flex flex-col items-center justify-center ">
          <p className="text-base font-medium mb-1">Preparing account brief</p>
          <div className="max-w-[340px] text-center gap-2 flex flex-col">
            <p>
              We're now busy analyzing and pulling together everything you need to know about this
              lead.
            </p>
            <p>Hang tight, the brief should be available in a moment.</p>
          </div>
        </div>
      </div>
    );

  return (
    <Editor
      size="sm"
      key={docId}
      useYjs={true}
      placeholder=""
      user_id={userId}
      namespace="leads"
      documentId={docId}
      user={presenceUser}
    />
  );
};
