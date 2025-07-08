import { UrlState } from 'src/types';
import { useUrlState } from 'src/hooks';
import { Icon } from 'src/components/Icon';
import { Button } from 'src/components/Button';
import { Toggle } from 'src/components/Toggle';
import { Select } from 'src/components/Select';
import { IconButton } from 'src/components/IconButton';
import { Popover, PopoverContent, PopoverTrigger } from 'src/components/Popover';

const orderByOptions = [
  { label: 'Updated', value: 'updated_at' },
  { label: 'Name', value: 'name' },
  { label: 'Industry', value: 'industry' },
  { label: 'Stage', value: 'stage' },
  { label: 'Country', value: 'country' },
];

export const Display = () => {
  const { getUrlState, setUrlState } = useUrlState<UrlState>();
  const { pipeline, group, desc, asc } = getUrlState();
  const orderBy = desc || asc;

  return (
    <Popover>
      <PopoverTrigger asChild>
        <Button
          size="xs"
          variant="ghost"
          colorScheme="gray"
          className="hidden md:flex"
          leftIcon={<Icon name="distribute-spacing-vertical" />}
        >
          Display
        </Button>
      </PopoverTrigger>
      <PopoverContent className="flex flex-col gap-2 w-[221px] p-3">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Icon name="recording-01" className="text-gray-500" />
            <span>Pipeline</span>
          </div>

          <Toggle
            size="sm"
            isChecked={pipeline !== 'hidden'}
            onChange={value => {
              setUrlState(params => ({
                ...params,
                pipeline: value ? 'visible' : 'hidden',
              }));
            }}
          />
        </div>

        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Icon name="rows-01" className="text-gray-500" />
            <span>Grouping</span>
          </div>

          <Toggle
            size="sm"
            isChecked={group !== 'none'}
            onChange={value => {
              setUrlState(params => ({
                ...params,
                group: value ? 'stage' : 'none',
              }));
            }}
          />
        </div>

        <div className="flex items-center justify-between gap-2">
          <div className="flex items-center gap-2">
            <Icon className="text-gray-500" name="arrow-switch-vertical-01" />
            <span>Ordering</span>
          </div>

          <div className="w-fit flex items-center gap-2">
            <Select
              size="xxs"
              isSearchable={false}
              menuWidth="fit-item"
              placeholder="Order by"
              options={orderByOptions}
              value={orderByOptions.find(option => option.value === (orderBy || 'updated_at'))}
              onChange={value => {
                setUrlState(({ desc, asc, ...rest }) => {
                  if (value.value === desc || value.value === asc) {
                    return rest;
                  }

                  return {
                    ...rest,
                    desc: value.value,
                  };
                });
              }}
            />

            <IconButton
              size="xxs"
              aria-label="icp"
              variant="outline"
              icon={<Icon name={asc ? 'arrows-up' : 'arrows-down'} />}
              onClick={() => {
                setUrlState(({ desc, asc, ...rest }) => {
                  if (desc && asc) {
                    return {
                      ...rest,
                    };
                  }

                  if (desc) {
                    return {
                      ...rest,
                      asc: desc,
                    };
                  }

                  if (asc) {
                    return {
                      ...rest,
                      desc: asc,
                    };
                  }

                  return {
                    ...rest,
                    asc: 'updated_at',
                  };
                });
              }}
            />
          </div>
        </div>
      </PopoverContent>
    </Popover>
  );
};
