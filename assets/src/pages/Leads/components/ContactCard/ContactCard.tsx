import { Icon } from 'src/components/Icon';
import { Avatar } from 'src/components/Avatar';

export const ContactCard = () => {
  return (
    <div>
      <div className="flex items-center gap-2 mb-2">
        <Avatar size="sm" icon={<Icon name="user-03" className="text-grayModern-700 size-6" />} />
        <div className="flex flex-col">
          <p className="text-sm font-medium">John Doe</p>
          <p>Director of Sales</p>
        </div>
      </div>
      <div className="ml-2">
        <div className="flex items-center gap-2 py-1.5">
          <Icon name="globe-05" className="text-gray-500 mr-2" />
          <p>
            <span>USA</span> <span>•</span>
            <span>New York</span> <span>•</span> <span>12345</span>
          </p>
        </div>
        <div className="flex items-center gap-2 py-1.5">
          <Icon name="git-timeline" className="text-gray-500 mr-2" />
          <p>
            3 years and 2 months at <span>Google</span>
          </p>
        </div>
        <div className="flex items-center gap-2 py-1.5">
          <Icon name="mail-02" className="text-gray-500 mr-2" />
          <p>john.doe@gmail.com</p>
        </div>
        <div className="flex items-center gap-2 py-1.5">
          <Icon name="phone" className="text-gray-500 mr-2" />
          <p>+1 (234) 567-890</p>
        </div>
        <div className="flex items-center gap-2 py-1.5">
          <Icon name="linkedin-solid" className="text-gray-500 mr-2" />
          <p>/john-doe</p>
        </div>
      </div>
    </div>
  );
};
