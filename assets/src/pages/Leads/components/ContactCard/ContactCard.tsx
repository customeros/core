import { usePage } from '@inertiajs/react';

import { Icon } from 'src/components/Icon';
import { Avatar } from 'src/components/Avatar';
import { Lead, TargetPersona } from 'src/types';
import { FeaturedIcon } from 'src/components/FeaturedIcon/FeaturedIcon';

export const ContactCard = () => {
  const page = usePage<{ leads: Lead[]; personas: TargetPersona[] }>();
  const personas: TargetPersona[] = page.props.personas || [];

  if (personas.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-12 w-full">
        <FeaturedIcon size="sm" className="mb-4">
          <Icon name="user-03" className="text-violet-600 size-8" />
        </FeaturedIcon>
        <div className="font-medium mb-2">No contacts yet</div>
        <div className="text-gray-500 max-w-md text-center text-base">
          We haven't found any contacts for this company yet. As soon as we find the right ones to
          talk to, we'll add them here.
        </div>
      </div>
    );
  }

  return (
    <div className="flex w-full flex-col gap-2 mt-4">
      {personas.map((persona, index) => (
        <div key={persona.id} className="flex flex-col px-2 py-1 bg-white">
          <div className="flex items-center gap-3 mb-2">
            <Avatar
              size="sm"
              icon={<Icon name="user-03" className="text-grayModern-700 size-6" />}
            />
            <div>
              <div className="font-medium">{persona.full_name}</div>
              <div>{persona.job_title}</div>
            </div>
          </div>
          <div className="flex flex-col gap-2">
            <div className="flex items-center gap-2 text-sm ml-10">
              {persona.location && (
                <>
                  <Icon name="globe-05" className="text-gray-500 mr-1" />
                  <span>{persona.location}</span>
                </>
              )}
            </div>
            <div className="flex items-center gap-2 text-sm  ml-10">
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
            {persona.work_email && (
              <div className="flex items-center gap-2 text-sm ml-10">
                <Icon name="mail-02" className="text-gray-500 mr-1" />
                <span>{persona.work_email}</span>
              </div>
            )}
            {persona.phone_number && (
              <div className="flex items-center gap-2 text-sm ml-10">
                <Icon name="phone" className="text-gray-500 mr-1" />
                <span>{persona.phone_number}</span>
              </div>
            )}
            {persona.linkedin && (
              <div className="flex items-center gap-2 text-sm ml-10">
                <Icon name="linkedin-solid" className="text-gray-500 mr-1" />
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
};
