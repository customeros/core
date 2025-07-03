import { Avatar } from 'src/components/Avatar';

export const ContactCard = () => {
  return (
    <div className="">
      <div className="flex items-center gap-2">
        <Avatar />
        <div className="flex flex-col">
          <p className="text-sm font-medium">John Doe</p>
          <p>Director of Sales</p>
        </div>
      </div>
    </div>
  );
};
