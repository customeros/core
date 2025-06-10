import { useState } from 'react';
import { Icon } from 'src/components/Icon/Icon';
import { IconButton } from 'src/components/IconButton';
import { Input } from 'src/components/Input';
import { Popover, PopoverContent, PopoverTrigger } from 'src/components/Popover';
import { usePage } from '@inertiajs/react';
import { Tenant, User, Lead } from 'src/types';
import { PageProps } from '@inertiajs/core';

const options = [
  {
    label: 'Tenant 1',
    value: 'tenant-1',
  },
  {
    label: 'Tenant 2',
    value: 'tenant-2',
  },
  {
    label: 'Tenant 3',
    value: 'tenant-3',
  },
  {
    label: 'Tenant 4',
    value: 'tenant-4',
  },
  {
    label: 'Tenant 5',
    value: 'tenant-5',
  },
  {
    label: 'Tenant 6',
    value: 'tenant-6',
  },
  {
    label: 'Tenant 7',
    value: 'tenant-7',
  },
  {
    label: 'linearapp',
    value: 'tenant_oyzsum09o246l5he',
  },
  {
    label: 'Tenant 9',
    value: 'tenant-9',
  },
];

export const TenantSwitcher = ({ children }: { children: React.ReactNode }) => {
  const page = usePage<PageProps & { tenant: Tenant; currentUser: User; companies: Lead[] }>();
  const [search, setSearch] = useState('');

  console.log(page.props);
  return (
    <Popover>
      <PopoverTrigger asChild>{children}</PopoverTrigger>
      <PopoverContent
        className="max-w-[260px] py-1 top-[10px] max-h-[300px] overflow-y-auto"
        onClick={e => e.stopPropagation()}
        alignOffset={10}
      >
        <div className="flex gap-2 items-center border-b border-gray-200 pb-0.5">
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
          {options
            .filter(option => option.label.toLowerCase().includes(search.toLowerCase()))
            .map(option => (
              <div
                key={option.value}
                className="flex items-center gap-2 py-1 hover:bg-gray-100 px-2 rounded-md"
              >
                <Icon name="building-03" />
                <span className="text-sm">{option.label}</span>
                {page.props.tenant.id === option.value && (
                  <Icon name="check" className="text-primary-500" />
                )}
              </div>
            ))}
        </div>
      </PopoverContent>
    </Popover>
  );
};
