import { Icon } from 'src/components/Icon';
import { Lead, Document } from 'src/types';
import { RootLayout } from 'src/layouts/Root';
import { Editor } from 'src/components/Editor/Editor';
import {
  ScrollAreaRoot,
  ScrollAreaThumb,
  ScrollAreaViewport,
  ScrollAreaScrollbar,
} from 'src/components/ScrollArea';

interface DocumentProps {
  lead: Lead;
  document: Document;
}

export default function Document({ document, lead }: DocumentProps) {
  const docId = document.id;
  const name = `${lead.name} Account Brief`;
  const icon = lead.icon;
  const strongFit = lead.icp_fit === 'strong';

  return (
    <RootLayout>
      <ScrollAreaRoot>
        <ScrollAreaViewport>
          <div className="relative w-full h-full bg-white px-6">
            <div className="relative bg-white h-full mx-auto pt-[2px] w-full md:min-w-[680px] max-w-[680px]">
              <div className="flex items-center justify-between mt-[1px]">
                <div className="flex items-center w-full justify-start mb-3 gap-2">
                  {icon ? (
                    <img
                      src={icon}
                      loading="lazy"
                      alt="Lead icon"
                      className="size-6 object-contain border border-gray-200 rounded flex-shrink-0"
                    />
                  ) : (
                    <div className="size-6 flex items-center justify-center border border-gray-200 rounded flex-shrink-0">
                      <Icon name="building-06" />
                    </div>
                  )}
                  <p className="text-[16px] font-medium text-gray-900">{name}</p>
                  {strongFit && (
                    <div className="bg-error-100 w-fit px-2 py-1 rounded-[4px] max-w-[100px] truncate flex items-center gap-1">
                      <Icon name="flame" className="w-[14px] h-[14px] text-error-500" />
                      <span className="text-error-700 text-xs">Strong fit</span>
                    </div>
                  )}
                </div>
              </div>
              <Editor useYjs size="sm" isReadOnly documentId={docId} namespace="documents" />

              <div className="h-20 w-full"></div>
            </div>
          </div>
        </ScrollAreaViewport>
        <ScrollAreaScrollbar orientation="vertical">
          <ScrollAreaThumb />
        </ScrollAreaScrollbar>
      </ScrollAreaRoot>
    </RootLayout>
  );
}
