import { usePresence } from 'src/providers/PresenceProvider';
import { UserHexagon } from '../UserHexagon';

export const UserPresence = () => {
  const { presentUsers, currentUserId } = usePresence();

  return (
    <div className="flex gap-1">
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
