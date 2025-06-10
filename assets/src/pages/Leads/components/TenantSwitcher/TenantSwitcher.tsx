import { useState, useEffect } from 'react';

import { Input } from 'src/components/Input';
import axios, { AxiosResponse } from 'axios';
import { Icon } from 'src/components/Icon/Icon';
import { Popover, PopoverContent, PopoverTrigger } from 'src/components/Popover';

export const TenantSwitcher = ({
  children,
  currentTenant,
  isAdmin,
}: {
  isAdmin: boolean;
  currentTenant: string;
  children: React.ReactNode;
}) => {
  const [search, setSearch] = useState('');
  const [tenants, setTenants] = useState<
    { id: string; name: string; workspace_name: string; workspace_icon_key: string }[]
  >([]);

  useEffect(() => {
    axios
      .get('/tenants')
      .then(
        (
          res: AxiosResponse<
            { id: string; name: string; workspace_name: string; workspace_icon_key: string }[]
          >
        ) => {
          setTenants(res.data);
        }
      );
  }, []);

  const handleSwitch = (tenantId: string) => {
    axios.post(`/tenants/switch`, { tenant_id: tenantId }).then(() => {
      window.location.reload();
    });
  };

  if (!isAdmin) {
    return children;
  }

  return (
    <Popover>
      <PopoverTrigger asChild>{children}</PopoverTrigger>
      <PopoverContent
        align="start"
        alignOffset={10}
        onClick={e => e.stopPropagation()}
        className="max-w-[260px] py-1 right-[19px] top-[10px] max-h-[300px] overflow-y-auto"
      >
        <div className="flex gap-2 items-center border-b border-gray-100 pb-0.5 pl-[9px]">
          <Icon name="search-sm" />
          <Input
            size="sm"
            value={search}
            className="w-full"
            variant="unstyled"
            placeholder="Search"
            onChange={e => setSearch(e.target.value)}
          />
        </div>
        <div className="flex flex-col gap-1 mt-1 cursor-pointer">
          {tenants
            .filter(option => option.workspace_name?.toLowerCase().includes(search?.toLowerCase()))
            .map(option => (
              <div
                key={option.id}
                onClick={() => handleSwitch(option.id)}
                className="flex items-center gap-2 py-1 justify-between hover:bg-gray-100 px-2 rounded-sm"
              >
                <div className="flex items-center gap-2">
                  {option.workspace_icon_key ? (
                    <img
                      className="w-4 h-4"
                      src={option.workspace_icon_key}
                      alt={option.workspace_name || option.name}
                    />
                  ) : (
                    <Icon name="building-03" />
                  )}
                  <span className="text-sm">{option.workspace_name || option.name}</span>
                </div>
                {currentTenant === option.id && <Icon name="check" className="text-primary-500" />}
              </div>
            ))}
        </div>
      </PopoverContent>
    </Popover>
  );
};
