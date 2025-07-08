import { usePage, WhenVisible } from '@inertiajs/react';

import { TargetPersona } from 'src/types';
import { Icon } from 'src/components/Icon';
import { Avatar } from 'src/components/Avatar';
import { IconButton } from 'src/components/IconButton';
import { toastSuccess } from 'src/components/Toast/success';
import { FeaturedIcon } from 'src/components/FeaturedIcon/FeaturedIcon';

export const ContactCard = () => {
  return (
    <WhenVisible data="personas" fallback={<div></div>}>
      <ContactCardContent />
    </WhenVisible>
  );
};

const EmptyState = () => {
  return (
    <div className="flex flex-col items-center justify-center  w-full">
      <FeaturedIcon className="mb-6 mt-[40px]">
        <Icon name="user-03" />
      </FeaturedIcon>
      <div className="font-medium mb-2">No contacts yet</div>
      <div className="max-w-[340px] text-center">
        We haven't found any contacts for this company yet. As soon as we find the right ones to
        talk to, we'll add them here.
      </div>
    </div>
  );
};

function ContactCardContent() {
  const page = usePage<{ personas?: TargetPersona[] }>();
  const personas: TargetPersona[] = page.props.personas || [];

  if (personas?.length === 0) {
    return <EmptyState />;
  }

  return (
    <div className="flex w-full flex-col gap-2 mt-4">
      {personas.map((persona, index) => (
        <div key={persona.id} className="flex flex-col px-2 py-1 bg-white">
          <div className="flex items-center gap-3 mb-2">
            <Avatar
              size="sm"
              variant="outlineCircle"
              icon={<Icon name="user-03" className="text-grayModern-700 size-6" />}
            />
            <div>
              <div className="font-medium">{persona.full_name}</div>
              <div>{persona.job_title}</div>
            </div>
          </div>
          <div className="flex flex-col ml-2 gap-2">
            <div className="flex items-center gap-2 text-sm">
              {persona.location && (
                <>
                  <Icon name="globe-05" className="text-gray-500 mr-1" />
                  <span>{persona.location}</span>
                </>
              )}
            </div>
            <div className="flex items-center gap-2 text-sm">
              {persona.time_current_position && (
                <>
                  <Icon name="git-timeline" className="text-gray-500 mr-1" />
                  <span>
                    {persona.time_current_position}
                    {persona.company_name && (
                      <>
                        {' '}
                        at <span>{persona.company_name}</span>
                      </>
                    )}
                  </span>
                </>
              )}
            </div>

            <div className="flex items-center gap-2 text-sm group">
              <Icon name="mail-02" className="text-gray-500 mr-1" />
              {persona.work_email ? (
                <>
                  <p>{persona.work_email}</p>
                  <IconButton
                    size="xxs"
                    variant="ghost"
                    aria-label="copy-email"
                    icon={<Icon name="copy-03" />}
                    className="group-hover:opacity-100 opacity-0"
                    onClick={() => {
                      if (persona.work_email) {
                        navigator.clipboard.writeText(persona.work_email);
                        toastSuccess('Email copied', 'email-copied');
                      }
                    }}
                  />
                </>
              ) : (
                <p className="text-gray-500">Not found yet</p>
              )}
            </div>
            <div className="flex items-center gap-2 text-sm group/phone">
              <Icon name="phone" className="text-gray-500 mr-1" />
              {persona.phone_number ? (
                <>
                  <p>{persona.phone_number}</p>
                  <IconButton
                    size="xxs"
                    variant="ghost"
                    aria-label="copy-phone-number"
                    icon={<Icon name="copy-03" />}
                    className="group-hover/phone:opacity-100 opacity-0"
                    onClick={() => {
                      if (persona.phone_number) {
                        navigator.clipboard.writeText(persona.phone_number);
                        toastSuccess('Phone number copied', 'phone-number-copied');
                      }
                    }}
                  />
                </>
              ) : (
                <p className="text-gray-500">Not found yet</p>
              )}
            </div>
            {persona.linkedin && (
              <div className="flex items-center gap-2 text-sm">
                <Icon
                  stroke="none"
                  fill="#667085"
                  fillRule="evenodd"
                  name="linkedin-solid"
                  className="text-gray-500 mr-1"
                />
                <a
                  target="_blank"
                  href={persona.linkedin}
                  rel="noopener noreferrer"
                  className="hover:underline"
                >
                  {persona.linkedin.replace('https://www.linkedin.com/in/', '/')}
                </a>
              </div>
            )}
          </div>
          {index !== personas.length - 1 && <div className="w-full h-[1px] bg-gray-200 my-3" />}
        </div>
      ))}
    </div>
  );
}
