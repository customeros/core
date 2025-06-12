import { usePresence } from 'src/providers/PresenceProvider';

import { UserHexagon } from '../UserHexagon';

export const UserPresence = () => {
  const { presentUsers, currentUserId } = usePresence();

  return (
    <div className="gap-1 hidden sm:flex md:flex lg:flex xl:flex 2xl:flex">
      {presentUsers.map((user, idx) => {
        return (
          <UserHexagon
            id={user?.user_id ?? ''}
            color={user?.color ?? ''}
            name={user?.username ?? ''}
            key={`${user?.user_id}-${idx}`}
            isCurrent={user?.user_id === currentUserId}
          />
        );
      })}
    </div>
  );
};
