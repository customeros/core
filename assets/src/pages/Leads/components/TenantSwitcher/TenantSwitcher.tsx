import { useEffect, useState } from 'react';
import { Icon } from 'src/components/Icon/Icon';
import { IconButton } from 'src/components/IconButton';
import { Input } from 'src/components/Input';
import { Popover, PopoverContent, PopoverTrigger } from 'src/components/Popover';
import { usePage } from '@inertiajs/react';
import { Tenant, User, Lead } from 'src/types';
import { PageProps } from '@inertiajs/core';
import axios, { AxiosResponse } from 'axios';

export const TenantSwitcher = ({
  children,
  currentTenant,
  isAdmin,
}: {
  children: React.ReactNode;
  currentTenant: string;
  isAdmin: boolean;
}) => {
  const [search, setSearch] = useState('');
  const [tenants, setTenants] = useState<
    { id: string; workspace_name: string; workspace_icon_key: string; name: string }[]
  >([]);

  useEffect(() => {
    axios
      .get('/tenants')
      .then(
        (
          res: AxiosResponse<
            { id: string; workspace_name: string; workspace_icon_key: string; name: string }[]
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
        className="max-w-[260px] py-1 right-[19px] top-[10px] max-h-[300px] overflow-y-auto"
        onClick={e => e.stopPropagation()}
        alignOffset={10}
      >
        <div className="flex gap-2 items-center border-b border-gray-100 pb-0.5 pl-[9px]">
          <Icon name="search-sm" />
          <Input
            placeholder="Search"
            className="w-full"
            size="sm"
            variant="unstyled"
            value={search}
            onChange={e => setSearch(e.target.value)}
          />
        </div>
        <div className="flex flex-col gap-1 mt-1 cursor-pointer">
          {tenants
            .filter(option => option.workspace_name?.toLowerCase().includes(search?.toLowerCase()))
            .map(option => (
              <div
                key={option.id}
                className="flex items-center gap-2 py-1 justify-between hover:bg-gray-100 px-2 rounded-sm"
                onClick={() => handleSwitch(option.id)}
              >
                <div className="flex items-center gap-2">
                  {option.workspace_icon_key ? (
                    <img
                      src={option.workspace_icon_key}
                      alt={option.workspace_name || option.name}
                      className="w-4 h-4"
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
